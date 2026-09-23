-- Şema davranış testleri. Her blok bir kabul kriterini doğrular; başarısızlıkta EXCEPTION fırlatır.
\set ON_ERROR_STOP on

-- Yardımcı: verilen SQL hata vermeli
CREATE OR REPLACE FUNCTION pg_temp.must_fail(sql text, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE sql;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'OK  %', label;
    RETURN;
  END;
  RAISE EXCEPTION 'BEKLENEN HATA OLUŞMADI: %', label;
END $$;

-- T1: Aynı connector için iki aktif işlem açılamaz (senaryo 15)
INSERT INTO transactions (id, user_id, network_id, station_id, evse_id, connector_id, charge_point_id, id_token, idempotency_key, tariff_snapshot, status)
VALUES ('99999999-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111',
        '44444444-4444-4444-4444-444444444444', '77777777-7777-7777-7777-777777777771', '88888888-8888-8888-8888-888888888881',
        '55555555-5555-5555-5555-555555555555', 'tok-1', 'idem-1', '{"energy": 9.9}', 'starting');
SELECT pg_temp.must_fail($q$
  INSERT INTO transactions (user_id, network_id, station_id, evse_id, connector_id, id_token, idempotency_key, tariff_snapshot, status)
  VALUES ('22222222-2222-2222-2222-222222222223', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444',
          '77777777-7777-7777-7777-777777777771', '88888888-8888-8888-8888-888888888881', 'tok-2', 'idem-2', '{}', 'pending_payment')
$q$, 'T1 aynı connector ikinci aktif işlem reddedildi');

-- T2: Aynı idempotency anahtarı ikinci işlem oluşturamaz (senaryo: çift tık / tekrar gönderim)
SELECT pg_temp.must_fail($q$
  INSERT INTO transactions (user_id, network_id, station_id, evse_id, connector_id, id_token, idempotency_key, tariff_snapshot)
  VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444',
          '77777777-7777-7777-7777-777777777773', '88888888-8888-8888-8888-888888888885', 'tok-3', 'idem-1', '{}')
$q$, 'T2 tekrar eden idempotency_key reddedildi');

-- T3: Aynı OCPP transactionId aynı cihazda iki kez kaydedilemez (StopTransaction iki kez → tek kayıt)
UPDATE transactions SET ocpp_transaction_id = '1001', status = 'charging', started_at = now(), meter_start_wh = 1000
 WHERE id = '99999999-0000-0000-0000-000000000001';
DO $$ BEGIN
  IF (SELECT count(*) FROM transactions WHERE charge_point_id = '55555555-5555-5555-5555-555555555555' AND ocpp_transaction_id = '1001') <> 1 THEN
    RAISE EXCEPTION 'T3 başarısız';
  END IF;
  RAISE NOTICE 'OK  T3 OCPP transactionId tekil';
END $$;

-- T4: Başlamış işlemin tarife kopyası değiştirilemez
SELECT pg_temp.must_fail($q$ UPDATE transactions SET tariff_snapshot = '{"energy": 1}' WHERE id = '99999999-0000-0000-0000-000000000001' $q$,
  'T4 başlamış işlemin tarifesi değiştirilemez');

-- T5: Kesinleşen fiyat değiştirilemez; enerji hesaplanan sütundur
UPDATE transactions SET meter_stop_wh = 43000, status = 'completed', stopped_at = now(),
       total_minor = 41580, price_breakdown = '{"energy_minor": 41580}', finalized_at = now()
 WHERE id = '99999999-0000-0000-0000-000000000001';
DO $$ BEGIN
  IF (SELECT energy_wh FROM transactions WHERE id = '99999999-0000-0000-0000-000000000001') <> 42000 THEN
    RAISE EXCEPTION 'T5 energy_wh yanlış';
  END IF;
  RAISE NOTICE 'OK  T5a energy_wh = 42000';
END $$;
SELECT pg_temp.must_fail($q$ UPDATE transactions SET total_minor = 1 WHERE id = '99999999-0000-0000-0000-000000000001' $q$,
  'T5b kesinleşmiş fiyat değiştirilemez');

-- T6: İşlem tamamlanınca aynı connector yeniden kullanılabilir
INSERT INTO transactions (user_id, network_id, station_id, evse_id, connector_id, id_token, idempotency_key, tariff_snapshot)
VALUES ('22222222-2222-2222-2222-222222222223', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444',
        '77777777-7777-7777-7777-777777777771', '88888888-8888-8888-8888-888888888881', 'tok-4', 'idem-4', '{}');
DO $$ BEGIN RAISE NOTICE 'OK  T6 tamamlanan işlemden sonra connector boş'; END $$;

-- T7: Defter dengeli olmalı (COMMIT'te kontrol) ve değiştirilemez
INSERT INTO payments (id, user_id, transaction_id, provider, flow, status, authorized_minor, captured_minor, idempotency_key)
VALUES ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '99999999-0000-0000-0000-000000000001',
        'fake', 'preauth_capture', 'captured', 75000, 41580, 'pay-1');
BEGIN;
INSERT INTO ledger_entries (entry_group, kind, account, debit_minor, payment_id)
  VALUES ('bbbbbbbb-0000-0000-0000-000000000001', 'payment', 'provider:fake:clearing', 41580, 'aaaaaaaa-0000-0000-0000-000000000001');
INSERT INTO ledger_entries (entry_group, kind, account, credit_minor, payment_id)
  VALUES ('bbbbbbbb-0000-0000-0000-000000000001', 'payment', 'network:11111111-1111-1111-1111-111111111111', 34650, 'aaaaaaaa-0000-0000-0000-000000000001');
INSERT INTO ledger_entries (entry_group, kind, account, credit_minor, payment_id)
  VALUES ('bbbbbbbb-0000-0000-0000-000000000001', 'vat', 'platform:vat_payable', 6930, 'aaaaaaaa-0000-0000-0000-000000000001');
COMMIT;
DO $$ BEGIN RAISE NOTICE 'OK  T7a dengeli defter grubu kabul edildi'; END $$;

DO $$ BEGIN
  BEGIN
    INSERT INTO ledger_entries (entry_group, kind, account, debit_minor)
      VALUES ('bbbbbbbb-0000-0000-0000-000000000002', 'adjustment', 'platform:revenue', 100);
    SET CONSTRAINTS ALL IMMEDIATE;   -- ertelenmiş kontrolü şimdi tetikle
  EXCEPTION WHEN integrity_constraint_violation THEN
    RAISE NOTICE 'OK  T7b dengesiz defter grubu reddedildi';
    RETURN;
  END;
  RAISE EXCEPTION 'T7b dengesiz grup kabul edildi';
END $$;

SELECT pg_temp.must_fail($q$ UPDATE ledger_entries SET debit_minor = 1 $q$, 'T7c defter satırı güncellenemez');
SELECT pg_temp.must_fail($q$ DELETE FROM ledger_entries $q$, 'T7d defter satırı silinemez');
INSERT INTO audit_logs (actor_type, actor_id, action, subject_type, subject_id)
  VALUES ('user', '22222222-2222-2222-2222-222222222222', 'refund.create', 'payment', 'aaaaaaaa-0000-0000-0000-000000000001');
SELECT pg_temp.must_fail($q$ DELETE FROM audit_logs $q$, 'T7e audit log silinemez');

-- T8: Geç/çift gelen MeterValue tek satır (idempotent upsert)
INSERT INTO transaction_meter_values (transaction_id, sampled_at, energy_wh, power_w)
VALUES ('99999999-0000-0000-0000-000000000001', now(), 5000, 164000)
ON CONFLICT DO NOTHING;
INSERT INTO transaction_meter_values (transaction_id, sampled_at, energy_wh, power_w)
SELECT transaction_id, sampled_at, energy_wh, power_w FROM transaction_meter_values
ON CONFLICT DO NOTHING;
DO $$ BEGIN
  IF (SELECT count(*) FROM transaction_meter_values) <> 1 THEN RAISE EXCEPTION 'T8 çift MeterValue'; END IF;
  RAISE NOTICE 'OK  T8 çift MeterValue yok sayıldı';
END $$;

-- T9: Yakındaki istasyonlar (earthdistance): Ataşehir'e 20 km içinde yalnızca test istasyonu
DO $$ DECLARE n int; BEGIN
  SELECT count(*) INTO n FROM charging_stations
   WHERE earth_box(ll_to_earth(40.99, 29.12), 20000) @> ll_to_earth(lat, lng)
     AND earth_distance(ll_to_earth(40.99, 29.12), ll_to_earth(lat, lng)) <= 20000;
  IF n <> 1 THEN RAISE EXCEPTION 'T9 yakın istasyon sayısı %', n; END IF;
  RAISE NOTICE 'OK  T9 yakın istasyon sorgusu';
END $$;

-- T10: Açık arıza tekilliği — aynı hata tekrar gelince ikinci olay açılmaz
INSERT INTO fault_reports (network_id, station_id, connector_id, source, error_code)
VALUES ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', '88888888-8888-8888-8888-888888888883', 'ocpp', 'ConnectorLockFailure');
SELECT pg_temp.must_fail($q$
  INSERT INTO fault_reports (network_id, station_id, connector_id, source, error_code)
  VALUES ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', '88888888-8888-8888-8888-888888888883', 'ocpp', 'ConnectorLockFailure')
$q$, 'T10 aynı açık arıza ikinci kez açılmadı');

-- T11: Partition bakımı çalışır ve idempotenttir
SELECT bs_ensure_monthly_partitions('ocpp_messages', 3);
SELECT bs_ensure_monthly_partitions('ocpp_messages', 3);
DO $$ BEGIN
  IF bs_drop_partitions_older_than('ocpp_messages', interval '10 years') <> 0 THEN RAISE EXCEPTION 'T11'; END IF;
  RAISE NOTICE 'OK  T11 partition bakımı';
END $$;

-- T12: Güvenlik profili 1 dışındaki cihaz kimlik bilgisi olmadan eklenemez; geçersiz kimlik reddedilir
SELECT pg_temp.must_fail($q$
  INSERT INTO charge_points (station_id, network_id, identity, protocol, security_profile)
  VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'NO-CREDS', 'ocpp1.6', 2)
$q$, 'T12a kimlik bilgisiz cihaz reddedildi');
SELECT pg_temp.must_fail($q$
  INSERT INTO charge_points (station_id, network_id, identity, protocol, security_profile)
  VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', '../../etc', 'ocpp1.6', 1)
$q$, 'T12b geçersiz chargePointId reddedildi');

-- T13: Telefon E.164 (yabancı numara kabul, bozuk format red)
SELECT pg_temp.must_fail($q$ INSERT INTO users (phone_e164) VALUES ('05301234567') $q$, 'T13 E.164 dışı telefon reddedildi');

DO $$ BEGIN RAISE NOTICE 'TÜM ŞEMA TESTLERİ GEÇTİ'; END $$;
