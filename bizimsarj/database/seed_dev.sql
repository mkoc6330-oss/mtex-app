-- Geliştirme verisi: 1 ağ, 1 test istasyonu (DC 180 kW, 2 EVSE × 2 connector), 1 AC istasyon,
-- 1 kullanıcı, 1 araç modeli. Üretimde ÇALIŞTIRILMAZ.
INSERT INTO charging_networks (id, slug, name, kind, commission_bps, auto_reset_policy)
VALUES ('11111111-1111-1111-1111-111111111111', 'bizimsarj', 'BizimŞarj', 'own', 0, 'soft_only');

INSERT INTO users (id, email, phone_e164, name, role)
VALUES ('22222222-2222-2222-2222-222222222222', 'test@bizimsarj.local', '+905300000000', 'Test Kullanıcı', 'user'),
       ('22222222-2222-2222-2222-222222222223', 'rider@example.com', '+491700000000', 'Yabancı Sürücü', 'user');

INSERT INTO vehicle_models (id, make, model, variant, usable_battery_kwh, max_ac_kw, max_dc_kw, connectors, consumption_wh_km)
VALUES ('33333333-3333-3333-3333-333333333333', 'Tesla', 'Model Y', 'Long Range', 75, 11, 250, '{TYPE2,CCS2}', 165),
       ('33333333-3333-3333-3333-333333333334', 'Togg', 'T10X', 'V2 Uzun Menzil', 88.5, 22, 150, '{TYPE2,CCS2}', 185);

INSERT INTO charging_stations (id, network_id, name, address, city, district, lat, lng, is_published)
VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111',
        'BİZİMŞARJ TEST İSTASYONU', 'Test Cad. No:1', 'İstanbul', 'Ataşehir', 40.9923, 29.1244, true),
       ('44444444-4444-4444-4444-444444444445', '11111111-1111-1111-1111-111111111111',
        'BizimŞarj AC Otopark', 'Otopark Sk. 5', 'Ankara', 'Çankaya', 39.9208, 32.8541, true);

INSERT INTO charge_points (id, station_id, network_id, identity, protocol, security_profile, basic_auth_hash)
VALUES ('55555555-5555-5555-5555-555555555555', '44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111',
        'BS-TEST-DC-01', 'ocpp1.6', 2, '$argon2id$dev-only'),
       ('55555555-5555-5555-5555-555555555556', '44444444-4444-4444-4444-444444444445', '11111111-1111-1111-1111-111111111111',
        'BS-TEST-AC-01', 'ocpp2.0.1', 2, '$argon2id$dev-only');

INSERT INTO tariffs (id, network_id, name) VALUES
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'DC Standart'),
  ('66666666-6666-6666-6666-666666666667', '11111111-1111-1111-1111-111111111111', 'AC Standart');
INSERT INTO tariff_rules (tariff_id, component, unit_price, unit, grace_minutes) VALUES
  ('66666666-6666-6666-6666-666666666666', 'energy',    9.9000, 'kwh',     0),
  ('66666666-6666-6666-6666-666666666666', 'start_fee', 0.0000, 'session', 0),
  ('66666666-6666-6666-6666-666666666666', 'idle',      5.0000, 'minute', 10),
  ('66666666-6666-6666-6666-666666666667', 'energy',    7.4900, 'kwh',     0),
  ('66666666-6666-6666-6666-666666666667', 'idle',      1.0000, 'minute', 60);

INSERT INTO evses (id, station_id, charge_point_id, ocpp_evse_id, current_type, power_class, advertised_power_kw, qr_code) VALUES
  ('77777777-7777-7777-7777-777777777771', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555', 1, 'DC', 'HPC', 180, 'BS-TR-0001-1'),
  ('77777777-7777-7777-7777-777777777772', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555', 2, 'DC', 'HPC', 180, 'BS-TR-0001-2'),
  ('77777777-7777-7777-7777-777777777773', '44444444-4444-4444-4444-444444444445', '55555555-5555-5555-5555-555555555556', 1, 'AC', 'AC', 22, 'BS-TR-0002-1');

INSERT INTO connectors (id, evse_id, ocpp_connector_id, standard, max_power_kw, tariff_id) VALUES
  ('88888888-8888-8888-8888-888888888881', '77777777-7777-7777-7777-777777777771', 1, 'CCS2',    180, '66666666-6666-6666-6666-666666666666'),
  ('88888888-8888-8888-8888-888888888882', '77777777-7777-7777-7777-777777777771', 2, 'CHADEMO',  50, '66666666-6666-6666-6666-666666666666'),
  ('88888888-8888-8888-8888-888888888883', '77777777-7777-7777-7777-777777777772', 1, 'CCS2',    180, '66666666-6666-6666-6666-666666666666'),
  ('88888888-8888-8888-8888-888888888884', '77777777-7777-7777-7777-777777777772', 2, 'CCS2',    180, '66666666-6666-6666-6666-666666666666'),
  ('88888888-8888-8888-8888-888888888885', '77777777-7777-7777-7777-777777777773', 1, 'TYPE2',    22, '66666666-6666-6666-6666-666666666667');
