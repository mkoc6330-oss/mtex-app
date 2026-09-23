-- =============================================================================
-- BizimŞarj — PostgreSQL 16 şeması (FAZ 2)
-- -----------------------------------------------------------------------------
-- Bu dosya şemanın TEK doğruluk kaynağıdır. Faz 3'te Laravel migration'ı bu
-- dosyayı çalıştırır (DB::unprepared) — tablo tanımları iki yerde tutulmaz.
--
-- İlkeler:
--   * Para daima "minor unit" (kuruş) BIGINT. Birim fiyatlar NUMERIC(12,4).
--   * Zaman daima TIMESTAMPTZ (UTC saklanır, TR saatine istemci çevirir).
--   * OCPP ham mesajı iş mantığı DEĞİLDİR: ocpp_messages yalnızca denetim içindir,
--     iş mantığı transactions / connectors / fault_reports üzerinden yürür.
--   * Yüksek hacimli tablolar (ocpp_messages, transaction_meter_values,
--     station_status) aylık partition'lıdır; saklama süresi = partition DROP.
--   * Finansal kayıtlar (ledger_entries, payment_transactions, audit_logs)
--     yalnızca eklenir (append-only) — UPDATE/DELETE tetikleyiciyle engellenir.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;   -- yakındaki istasyon sorgusu (PostGIS gerekmez)

-- -----------------------------------------------------------------------------
-- Yardımcılar
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION bs_touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION bs_forbid_mutation() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% tablosu değiştirilemez (append-only): % reddedildi', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'integrity_constraint_violation';
END $$;

-- Aylık partition üretici. Laravel scheduler her gün çağırır:
--   SELECT bs_ensure_monthly_partitions('ocpp_messages', 2);
CREATE OR REPLACE FUNCTION bs_ensure_monthly_partitions(parent regclass, months_ahead int DEFAULT 2)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  m date := date_trunc('month', now() - interval '1 month')::date;
  last date := (date_trunc('month', now()) + make_interval(months => months_ahead))::date;
  part text;
BEGIN
  WHILE m <= last LOOP
    part := format('%s_%s', parent::text, to_char(m, 'YYYYMM'));
    IF to_regclass(part) IS NULL THEN
      EXECUTE format('CREATE TABLE %I PARTITION OF %s FOR VALUES FROM (%L) TO (%L)',
                     part, parent, m, (m + interval '1 month')::date);
    END IF;
    m := (m + interval '1 month')::date;
  END LOOP;
END $$;

-- Saklama süresi dolan partition'ları düşürür:
--   SELECT bs_drop_partitions_older_than('ocpp_messages', interval '90 days');
CREATE OR REPLACE FUNCTION bs_drop_partitions_older_than(parent regclass, keep interval)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
  r record;
  dropped int := 0;
  cutoff date := date_trunc('month', now() - keep)::date;
BEGIN
  FOR r IN
    SELECT c.relname
    FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
    WHERE i.inhparent = parent
  LOOP
    IF to_date(right(r.relname, 6), 'YYYYMM') < cutoff THEN
      EXECUTE format('DROP TABLE %I', r.relname);
      dropped := dropped + 1;
    END IF;
  END LOOP;
  RETURN dropped;
END $$;

-- -----------------------------------------------------------------------------
-- Enum'lar (değer eklemek kolay, silmek zor — bilinçli olarak dar tutuldu)
-- -----------------------------------------------------------------------------
CREATE TYPE bs_current_type        AS ENUM ('AC', 'DC');
CREATE TYPE bs_power_class         AS ENUM ('AC', 'DC', 'HPC');           -- HPC: >= 150 kW DC
CREATE TYPE bs_connector_standard  AS ENUM ('TYPE2', 'CCS2', 'CHADEMO', 'GBT_DC', 'TYPE1', 'CCS1', 'NACS', 'SCHUKO', 'OTHER');
CREATE TYPE bs_ocpp_protocol       AS ENUM ('ocpp1.6', 'ocpp2.0.1');
-- OCPP 1.6 + 2.0.1 durumlarının ortak kümesi (sürüm sürücüsü buraya eşler)
CREATE TYPE bs_connector_status    AS ENUM ('AVAILABLE', 'PREPARING', 'CHARGING', 'SUSPENDED_EV', 'SUSPENDED_EVSE',
                                            'FINISHING', 'RESERVED', 'UNAVAILABLE', 'FAULTED', 'OCCUPIED', 'UNKNOWN');
-- Kullanıcıya gösterilen tazelik (13. madde)
CREATE TYPE bs_freshness           AS ENUM ('LIVE', 'RECENT', 'STALE', 'UNKNOWN');
-- Haritadaki pin durumu
CREATE TYPE bs_display_state       AS ENUM ('AVAILABLE', 'BUSY', 'VERIFY', 'FAULT', 'UNKNOWN');
CREATE TYPE bs_station_source      AS ENUM ('ocpp', 'ocpi', 'partner_api', 'crowd');
CREATE TYPE bs_tx_status           AS ENUM ('pending_payment', 'authorized', 'starting', 'charging', 'suspended',
                                            'finishing', 'completed', 'failed', 'cancelled');
CREATE TYPE bs_payment_status      AS ENUM ('created', 'authorized', 'captured', 'voided', 'failed', 'refunded', 'partially_refunded');
CREATE TYPE bs_checkin_kind        AS ENUM ('working', 'slow', 'not_starting', 'payment_failed', 'connector_broken', 'queue');
CREATE TYPE bs_fault_status        AS ENUM ('open', 'acknowledged', 'action_pending', 'resolved');
CREATE TYPE bs_member_role         AS ENUM ('owner', 'manager', 'technician', 'viewer');
CREATE TYPE bs_user_role           AS ENUM ('user', 'support', 'admin');

-- =============================================================================
-- KİMLİK / KİRACILAR
-- =============================================================================

-- Şarj ağı = operatör = kiracı (multi-tenant sınırı). Kendi ağımız da bir satırdır.
CREATE TABLE charging_networks (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                 citext NOT NULL UNIQUE,
  name                 text NOT NULL,
  legal_name           text,
  tax_number           text,
  epdk_license_no      text,                         -- şarj hizmeti lisansı (varsa)
  kind                 text NOT NULL DEFAULT 'partner' CHECK (kind IN ('own', 'partner', 'roaming')),
  integration          bs_station_source NOT NULL DEFAULT 'ocpp',
  support_phone        text,
  support_email        citext,
  commission_bps       int NOT NULL DEFAULT 0 CHECK (commission_bps BETWEEN 0 AND 10000),  -- 1000 = %10
  auto_reset_policy    text NOT NULL DEFAULT 'never' CHECK (auto_reset_policy IN ('never', 'soft_only', 'soft_then_hard')),
  is_active            boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email                citext UNIQUE,
  phone_e164           text UNIQUE CHECK (phone_e164 ~ '^\+[1-9][0-9]{6,14}$'),  -- yabancı numara desteklenir
  name                 text,
  password_hash        text,                          -- null: yalnızca OTP / e-posta bağlantısı
  role                 bs_user_role NOT NULL DEFAULT 'user',
  locale               text NOT NULL DEFAULT 'tr',
  country_code         char(2) NOT NULL DEFAULT 'TR',
  reputation           numeric(4,3) NOT NULL DEFAULT 1.000 CHECK (reputation BETWEEN 0 AND 2),
  email_verified_at    timestamptz,
  phone_verified_at    timestamptz,
  is_blocked           boolean NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  deleted_at           timestamptz,                   -- KVKK silme talebi: anonimleştir + işaretle
  CHECK (email IS NOT NULL OR phone_e164 IS NOT NULL)
);

-- Operatör paneli RBAC: bir kullanıcı birden çok ağda farklı rolde olabilir.
CREATE TABLE network_members (
  network_id           uuid NOT NULL REFERENCES charging_networks(id) ON DELETE CASCADE,
  user_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role                 bs_member_role NOT NULL,
  created_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (network_id, user_id)
);

-- Refresh token rotasyonu: aynı ailede eski token tekrar kullanılırsa tüm aile iptal edilir.
CREATE TABLE auth_refresh_tokens (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family_id            uuid NOT NULL,
  token_hash           bytea NOT NULL UNIQUE,         -- SHA-256; düz token saklanmaz
  device_label         text,
  expires_at           timestamptz NOT NULL,
  rotated_at           timestamptz,
  revoked_at           timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON auth_refresh_tokens (family_id);

-- =============================================================================
-- ARAÇLAR
-- =============================================================================
CREATE TABLE vehicle_models (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  make                 text NOT NULL,
  model                text NOT NULL,
  variant              text NOT NULL DEFAULT '',
  year_from            smallint,
  year_to              smallint,
  usable_battery_kwh   numeric(6,2) NOT NULL CHECK (usable_battery_kwh > 0),
  max_ac_kw            numeric(6,2) NOT NULL,
  max_dc_kw            numeric(6,2),
  connectors           bs_connector_standard[] NOT NULL,
  consumption_wh_km    numeric(6,1) NOT NULL DEFAULT 170,
  -- [{ "soc": 10, "kw": 170 }, ...] — yoksa basit tahmin kullanılır (17. madde)
  charging_curve       jsonb,
  UNIQUE (make, model, variant, year_from)
);

CREATE TABLE vehicles (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_model_id     uuid NOT NULL REFERENCES vehicle_models(id),
  nickname             text,
  is_default           boolean NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX vehicles_one_default ON vehicles (user_id) WHERE is_default;

-- =============================================================================
-- İSTASYONLAR: Lokasyon → (Şarj cihazı) → EVSE → Connector
-- OCPI Location/EVSE/Connector modeliyle birebir — roaming'e hazır.
-- =============================================================================
CREATE TABLE charging_stations (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  network_id           uuid NOT NULL REFERENCES charging_networks(id),
  source               bs_station_source NOT NULL DEFAULT 'ocpp',
  external_ref         text,                          -- OCPI location id / partner id (dedup anahtarı)
  name                 text NOT NULL,
  address              text NOT NULL,
  city                 text NOT NULL,
  district             text,
  country_code         char(2) NOT NULL DEFAULT 'TR',
  lat                  double precision NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng                  double precision NOT NULL CHECK (lng BETWEEN -180 AND 180),
  opening_hours        jsonb,                         -- null + is_24_7 = her zaman açık
  is_24_7              boolean NOT NULL DEFAULT true,
  parking_info         text,
  amenities            text[] NOT NULL DEFAULT '{}',
  is_published         boolean NOT NULL DEFAULT false,
  -- ↓ Motorların yazdığı denormalize alanlar (harita tek sorguda çizilsin diye)
  last_seen_at         timestamptz,
  last_success_session_at timestamptz,
  last_fault_at        timestamptz,
  last_checkin_at      timestamptz,
  freshness            bs_freshness NOT NULL DEFAULT 'UNKNOWN',
  display_state        bs_display_state NOT NULL DEFAULT 'UNKNOWN',
  reliability_score    smallint CHECK (reliability_score BETWEEN 0 AND 100),
  reliability_explain  jsonb,                         -- [{ "factor": "ocpp_live", "points": 30, "text": "..." }]
  reliability_at       timestamptz,
  connectors_total     smallint NOT NULL DEFAULT 0,
  connectors_available smallint NOT NULL DEFAULT 0,
  connectors_faulted   smallint NOT NULL DEFAULT 0,
  max_power_kw         numeric(6,1),
  min_energy_price     numeric(12,4),                 -- kWh başı en düşük fiyat (KDV dahil) — filtre/sıralama için
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (network_id, external_ref)
);
CREATE INDEX charging_stations_geo ON charging_stations USING gist (ll_to_earth(lat, lng));
CREATE INDEX ON charging_stations (network_id);
CREATE TRIGGER charging_stations_touch BEFORE UPDATE ON charging_stations
  FOR EACH ROW EXECUTE FUNCTION bs_touch_updated_at();

-- Fiziksel şarj cihazı = OCPP kimliği (chargePointId / stationId). Kimlik doğrulama burada.
CREATE TABLE charge_points (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id           uuid NOT NULL REFERENCES charging_stations(id),
  network_id           uuid NOT NULL REFERENCES charging_networks(id),
  identity             text NOT NULL UNIQUE CHECK (identity ~ '^[A-Za-z0-9._:-]{1,48}$'),  -- URL'deki kimlik
  protocol             bs_ocpp_protocol NOT NULL,
  security_profile     smallint NOT NULL DEFAULT 2 CHECK (security_profile IN (1, 2, 3)),  -- 1 yalnızca geliştirme
  basic_auth_hash      text,                          -- argon2id; profil 2
  client_cert_sha256   text,                          -- profil 3 (mTLS)
  ip_allowlist         cidr[],                        -- opsiyonel
  registration_status  text NOT NULL DEFAULT 'Pending' CHECK (registration_status IN ('Pending', 'Accepted', 'Rejected')),
  vendor               text,
  model                text,
  serial_number        text,
  firmware_version     text,
  iccid                text,
  heartbeat_interval_s int NOT NULL DEFAULT 300,
  is_online            boolean NOT NULL DEFAULT false,
  last_boot_at         timestamptz,
  last_heartbeat_at    timestamptz,
  last_seen_at         timestamptz,                   -- herhangi bir mesajın geldiği son an
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CHECK (security_profile = 1 OR basic_auth_hash IS NOT NULL OR client_cert_sha256 IS NOT NULL)
);
CREATE INDEX ON charge_points (station_id);
CREATE TRIGGER charge_points_touch BEFORE UPDATE ON charge_points
  FOR EACH ROW EXECUTE FUNCTION bs_touch_updated_at();

-- EVSE: 2.0.1'de evseId; 1.6'da her connectorId bir EVSE sayılır.
CREATE TABLE evses (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id           uuid NOT NULL REFERENCES charging_stations(id),
  charge_point_id      uuid REFERENCES charge_points(id),     -- OCPI/partner kaynaklıysa null
  ocpp_evse_id         int CHECK (ocpp_evse_id > 0),
  evse_uid             text,                                   -- OCPI EVSE uid / QR kodundaki kimlik
  current_type         bs_current_type NOT NULL,
  power_class          bs_power_class NOT NULL,
  advertised_power_kw  numeric(6,1) NOT NULL,                  -- 15. madde: ilan edilen
  last_power_kw        numeric(6,1),                           -- son ölçülen anlık güç
  last_power_at        timestamptz,
  avg_power_kw_last20  numeric(6,1),                           -- son 20 seans ortalaması
  peak_power_kw_last20 numeric(6,1),
  qr_code              text UNIQUE,
  created_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (charge_point_id, ocpp_evse_id),
  CHECK (charge_point_id IS NULL OR ocpp_evse_id IS NOT NULL)
);
CREATE INDEX ON evses (station_id);

CREATE TABLE tariffs (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  network_id           uuid NOT NULL REFERENCES charging_networks(id),
  name                 text NOT NULL,
  currency             char(3) NOT NULL DEFAULT 'TRY',
  vat_bps              int NOT NULL DEFAULT 2000,      -- %20 KDV (şarj hizmeti)
  prices_include_vat   boolean NOT NULL DEFAULT true,  -- EPDK: son kullanıcıya KDV dahil fiyat gösterilir
  valid_from           timestamptz NOT NULL DEFAULT now(),
  valid_to             timestamptz,
  version              int NOT NULL DEFAULT 1,
  is_active            boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now()
);

-- Tarifenin bileşenleri. Bir kural yayınlandıktan sonra DEĞİŞMEZ; değişiklik = yeni sürüm tarife.
CREATE TABLE tariff_rules (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tariff_id            uuid NOT NULL REFERENCES tariffs(id) ON DELETE CASCADE,
  component            text NOT NULL CHECK (component IN ('energy', 'start_fee', 'time', 'idle', 'parking', 'min_fee', 'discount_pct')),
  unit_price           numeric(12,4) NOT NULL CHECK (unit_price >= 0),  -- TL/kWh, TL/seans, TL/dk ...
  unit                 text NOT NULL CHECK (unit IN ('kwh', 'session', 'minute', 'hour', 'percent')),
  grace_minutes        int NOT NULL DEFAULT 0,          -- idle: şarj bittikten sonra ücretsiz süre
  step_size            int NOT NULL DEFAULT 1,          -- ör. dakika ücreti 1 dk adımla
  restrictions         jsonb NOT NULL DEFAULT '{}',     -- { "days": [1,2], "from": "22:00", "to": "06:00", "min_kw": 50 }
  priority             int NOT NULL DEFAULT 0,
  label                text                             -- kampanya adı vb.
);
CREATE INDEX ON tariff_rules (tariff_id);

CREATE TABLE connectors (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evse_id              uuid NOT NULL REFERENCES evses(id) ON DELETE CASCADE,
  ocpp_connector_id    int NOT NULL DEFAULT 1 CHECK (ocpp_connector_id > 0),
  standard             bs_connector_standard NOT NULL,
  format               text NOT NULL DEFAULT 'cable' CHECK (format IN ('socket', 'cable')),
  max_power_kw         numeric(6,1) NOT NULL,
  max_voltage          int,
  max_amperage         int,
  tariff_id            uuid REFERENCES tariffs(id),
  -- ↓ Anlık durum (OCPP'den ham) + durum motorunun kararı (etkin durum)
  ocpp_status          bs_connector_status NOT NULL DEFAULT 'UNKNOWN',
  ocpp_status_at       timestamptz,
  error_code           text,
  vendor_error_code    text,
  effective_status     bs_connector_status NOT NULL DEFAULT 'UNKNOWN',
  effective_reason     text,                           -- "heartbeat 2 saat önce" gibi açıklama
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (evse_id, ocpp_connector_id)
);
CREATE TRIGGER connectors_touch BEFORE UPDATE ON connectors
  FOR EACH ROW EXECUTE FUNCTION bs_touch_updated_at();

-- Durum DEĞİŞİMİ geçmişi (her StatusNotification değil, yalnızca değişimler).
-- Arıza oranı ve müsaitlik istatistiği bundan üretilir. Saklama: 13 ay.
CREATE TABLE station_status (
  id                   bigint GENERATED ALWAYS AS IDENTITY,
  connector_id         uuid NOT NULL,
  station_id           uuid NOT NULL,
  status               bs_connector_status NOT NULL,
  error_code           text,
  source               text NOT NULL CHECK (source IN ('ocpp', 'engine', 'operator', 'partner_api')),
  changed_at           timestamptz NOT NULL,
  PRIMARY KEY (id, changed_at)
) PARTITION BY RANGE (changed_at);
CREATE INDEX ON station_status (station_id, changed_at DESC);

-- Saatlik agregat (11. madde): ham veri silinse de istatistik kalır. Kalıcı.
CREATE TABLE station_telemetry (
  evse_id              uuid NOT NULL REFERENCES evses(id) ON DELETE CASCADE,
  hour                 timestamptz NOT NULL,
  sessions             int NOT NULL DEFAULT 0,
  sessions_failed      int NOT NULL DEFAULT 0,
  energy_wh            bigint NOT NULL DEFAULT 0,
  avg_power_kw         numeric(6,1),
  peak_power_kw        numeric(6,1),
  minutes_available    smallint NOT NULL DEFAULT 0,
  minutes_charging     smallint NOT NULL DEFAULT 0,
  minutes_faulted      smallint NOT NULL DEFAULT 0,
  minutes_offline      smallint NOT NULL DEFAULT 0,
  reliability_avg      smallint,
  PRIMARY KEY (evse_id, hour)
);

-- =============================================================================
-- OCPP
-- =============================================================================

-- Her WebSocket bağlantısı bir satır: bağlanma/kopma denetimi + hangi gateway düğümünde.
CREATE TABLE ocpp_connections (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  charge_point_id      uuid NOT NULL REFERENCES charge_points(id),
  protocol             bs_ocpp_protocol NOT NULL,
  gateway_node         text NOT NULL,
  remote_ip            inet,
  tls_version          text,
  client_cert_sha256   text,
  connected_at         timestamptz NOT NULL DEFAULT now(),
  disconnected_at      timestamptz,
  disconnect_reason    text
);
CREATE INDEX ON ocpp_connections (charge_point_id, connected_at DESC);
CREATE UNIQUE INDEX ocpp_connections_one_open ON ocpp_connections (charge_point_id) WHERE disconnected_at IS NULL;

-- ÖNEMLİ mesajların denetim kaydı (Boot, Status değişimi, Start/Stop/TransactionEvent,
-- komutlar ve yanıtları, CALLERROR). Heartbeat ve MeterValues buraya YAZILMAZ —
-- onlar gateway'in sıkıştırılmış dosya log'una gider. Saklama: 90 gün.
CREATE TABLE ocpp_messages (
  id                   bigint GENERATED ALWAYS AS IDENTITY,
  charge_point_id      uuid NOT NULL,
  connection_id        uuid,
  direction            char(3) NOT NULL CHECK (direction IN ('in', 'out')),
  message_type         smallint NOT NULL CHECK (message_type IN (2, 3, 4)),  -- CALL / CALLRESULT / CALLERROR
  unique_id            text NOT NULL,
  action               text,
  payload              jsonb NOT NULL,
  error_code           text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX ON ocpp_messages (charge_point_id, created_at DESC);
-- Replay/duplicate tespiti: aynı cihazdan aynı uniqueId'li CALL tekrar gelirse
CREATE INDEX ON ocpp_messages (charge_point_id, unique_id);

-- =============================================================================
-- ŞARJ İŞLEMLERİ (domain transaction — OCPP transaction'ından BAĞIMSIZ)
-- =============================================================================
CREATE TABLE transactions (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid REFERENCES users(id),               -- null: RFID/ad-hoc
  vehicle_id           uuid REFERENCES vehicles(id),
  network_id           uuid NOT NULL REFERENCES charging_networks(id),
  station_id           uuid NOT NULL REFERENCES charging_stations(id),
  evse_id              uuid NOT NULL REFERENCES evses(id),
  connector_id         uuid NOT NULL REFERENCES connectors(id),
  charge_point_id      uuid REFERENCES charge_points(id),
  protocol             bs_ocpp_protocol,
  -- 1.6: CSMS'in verdiği tamsayı; 2.0.1: istasyonun verdiği string. İkisi de metin tutulur.
  ocpp_transaction_id  text,
  id_token             text NOT NULL,                  -- uygulama başlatmasında tek kullanımlık token
  id_token_type        text NOT NULL DEFAULT 'Central' CHECK (id_token_type IN ('Central', 'ISO14443', 'eMAID', 'KeyCode', 'Local')),
  status               bs_tx_status NOT NULL DEFAULT 'pending_payment',
  idempotency_key      text NOT NULL UNIQUE,           -- 37. madde: aynı istek iki şarj başlatamaz
  start_requested_at   timestamptz NOT NULL DEFAULT now(),
  started_at           timestamptz,
  charging_ended_at    timestamptz,                    -- enerji akışı bitti (idle sayacı buradan başlar)
  stopped_at           timestamptz,                    -- fiş çekildi / işlem kapandı
  stop_reason          text,
  meter_start_wh       bigint,
  meter_stop_wh        bigint,
  energy_wh            bigint GENERATED ALWAYS AS (meter_stop_wh - meter_start_wh) STORED,
  avg_power_kw         numeric(6,1),
  peak_power_kw        numeric(6,1),
  soc_start            smallint CHECK (soc_start BETWEEN 0 AND 100),
  soc_end              smallint CHECK (soc_end BETWEEN 0 AND 100),
  was_offline          boolean NOT NULL DEFAULT false, -- cihaz çevrimdışıyken kuyruklayıp sonradan gönderdi
  -- ↓ Fiyat: başlangıçta tarifenin DONDURULMUŞ kopyası; bitişte kesin döküm
  tariff_id            uuid REFERENCES tariffs(id),
  tariff_snapshot      jsonb NOT NULL,
  quote                jsonb,                          -- başlamadan önce gösterilen tahmin
  price_breakdown      jsonb,
  total_minor          bigint CHECK (total_minor >= 0),
  currency             char(3) NOT NULL DEFAULT 'TRY',
  finalized_at         timestamptz,                    -- set edildikten sonra fiyat alanları değişmez
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CHECK (meter_stop_wh IS NULL OR meter_start_wh IS NULL OR meter_stop_wh >= meter_start_wh)
);
CREATE UNIQUE INDEX transactions_ocpp_id ON transactions (charge_point_id, ocpp_transaction_id)
  WHERE ocpp_transaction_id IS NOT NULL;
-- 38/15: iki kullanıcı aynı connector'a aynı anda başlatamaz — veritabanı garantisi.
CREATE UNIQUE INDEX transactions_one_active_per_connector ON transactions (connector_id)
  WHERE status IN ('pending_payment', 'authorized', 'starting', 'charging', 'suspended', 'finishing');
CREATE INDEX ON transactions (user_id, created_at DESC);
CREATE INDEX ON transactions (station_id, stopped_at DESC);
CREATE TRIGGER transactions_touch BEFORE UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION bs_touch_updated_at();

CREATE OR REPLACE FUNCTION bs_transactions_freeze_price() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.finalized_at IS NOT NULL AND (
       NEW.total_minor     IS DISTINCT FROM OLD.total_minor OR
       NEW.price_breakdown IS DISTINCT FROM OLD.price_breakdown OR
       NEW.tariff_snapshot IS DISTINCT FROM OLD.tariff_snapshot OR
       NEW.meter_start_wh  IS DISTINCT FROM OLD.meter_start_wh OR
       NEW.meter_stop_wh   IS DISTINCT FROM OLD.meter_stop_wh OR
       NEW.finalized_at    IS DISTINCT FROM OLD.finalized_at) THEN
    RAISE EXCEPTION 'Kesinleşmiş işlemin fiyatı değiştirilemez (tx %). Düzeltme = refund/ledger kaydı.', OLD.id
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  IF OLD.tariff_snapshot IS DISTINCT FROM NEW.tariff_snapshot AND OLD.started_at IS NOT NULL THEN
    RAISE EXCEPTION 'Başlamış işlemin tarife kopyası değiştirilemez (tx %)', OLD.id
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER transactions_freeze_price BEFORE UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION bs_transactions_freeze_price();

-- Seans ölçümleri. Saklama 90 gün; seans özeti transactions'ta kalıcıdır.
CREATE TABLE transaction_meter_values (
  transaction_id       uuid NOT NULL,
  sampled_at           timestamptz NOT NULL,
  energy_wh            bigint,
  power_w              int,
  current_a            numeric(7,2),
  voltage_v            numeric(7,2),
  soc                  smallint,
  context              text,                            -- Sample.Periodic, Transaction.Begin ...
  PRIMARY KEY (transaction_id, sampled_at)             -- geç/çift gelen MeterValue idempotent
) PARTITION BY RANGE (sampled_at);

-- =============================================================================
-- ÖDEME (sağlayıcıdan bağımsız) + DEFTER
-- =============================================================================

-- Kart bilgisi SAKLANMAZ; yalnızca sağlayıcının token'ı.
CREATE TABLE payment_methods (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider             text NOT NULL,                   -- 'iyzico', 'paytr', 'fake' ...
  provider_customer_ref text NOT NULL,
  provider_token       text NOT NULL,
  brand                text,
  last4                char(4),
  exp_month            smallint,
  exp_year             smallint,
  is_default           boolean NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now(),
  revoked_at           timestamptz,
  UNIQUE (provider, provider_token)
);

-- Ödeme durumu, şarj durumundan AYRI tutulur (25. madde).
CREATE TABLE payments (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid REFERENCES users(id),
  transaction_id       uuid REFERENCES transactions(id),
  payment_method_id    uuid REFERENCES payment_methods(id),
  provider             text NOT NULL,
  provider_payment_id  text,
  flow                 text NOT NULL CHECK (flow IN ('preauth_capture', 'sale')),
  status               bs_payment_status NOT NULL DEFAULT 'created',
  authorized_minor     bigint NOT NULL DEFAULT 0 CHECK (authorized_minor >= 0),
  captured_minor       bigint NOT NULL DEFAULT 0 CHECK (captured_minor >= 0),
  refunded_minor       bigint NOT NULL DEFAULT 0 CHECK (refunded_minor >= 0),
  currency             char(3) NOT NULL DEFAULT 'TRY',
  idempotency_key      text NOT NULL UNIQUE,
  needs_reconciliation boolean NOT NULL DEFAULT false,  -- callback gelmedi / belirsiz durum
  last_error           text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_payment_id),
  CHECK (captured_minor <= authorized_minor OR flow = 'sale'),
  CHECK (refunded_minor <= captured_minor)
);
CREATE INDEX payments_reconcile ON payments (updated_at) WHERE needs_reconciliation;
CREATE TRIGGER payments_touch BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION bs_touch_updated_at();

-- Sağlayıcıyla her istek/yanıt/webhook — append-only. Kart verisi maskelenmiş olmalı.
CREATE TABLE payment_transactions (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payment_id           uuid NOT NULL REFERENCES payments(id),
  operation            text NOT NULL CHECK (operation IN ('preauth', 'capture', 'void', 'sale', 'refund', 'webhook', 'status_query')),
  idempotency_key      text,
  provider_ref         text,
  amount_minor         bigint,
  succeeded            boolean,
  http_status          smallint,
  signature_valid      boolean,                         -- webhook imza doğrulaması sonucu
  response             jsonb,
  created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON payment_transactions (payment_id);
CREATE TRIGGER payment_transactions_append_only BEFORE UPDATE OR DELETE ON payment_transactions
  FOR EACH ROW EXECUTE FUNCTION bs_forbid_mutation();

CREATE TABLE refunds (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id           uuid NOT NULL REFERENCES payments(id),
  transaction_id       uuid REFERENCES transactions(id),
  amount_minor         bigint NOT NULL CHECK (amount_minor > 0),
  reason               text NOT NULL,
  status               text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'succeeded', 'failed')),
  provider_ref         text,
  idempotency_key      text NOT NULL UNIQUE,
  requested_by         uuid REFERENCES users(id),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

-- Değişmez çift taraflı defter (26. madde). Her para hareketi = dengeli bir entry_group.
-- account örnekleri: 'user:<uuid>', 'network:<uuid>', 'platform:revenue',
--                    'platform:vat_payable', 'provider:iyzico:clearing'
CREATE TABLE ledger_entries (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entry_group          uuid NOT NULL,
  kind                 text NOT NULL CHECK (kind IN ('payment', 'refund', 'commission', 'operator_payout', 'vat', 'adjustment', 'promo_credit')),
  account              text NOT NULL,
  debit_minor          bigint NOT NULL DEFAULT 0 CHECK (debit_minor >= 0),
  credit_minor         bigint NOT NULL DEFAULT 0 CHECK (credit_minor >= 0),
  currency             char(3) NOT NULL DEFAULT 'TRY',
  transaction_id       uuid REFERENCES transactions(id),
  payment_id           uuid REFERENCES payments(id),
  refund_id            uuid REFERENCES refunds(id),
  memo                 text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  CHECK ((debit_minor = 0) <> (credit_minor = 0))
);
CREATE INDEX ON ledger_entries (entry_group);
CREATE INDEX ON ledger_entries (account, created_at);
CREATE TRIGGER ledger_entries_append_only BEFORE UPDATE OR DELETE ON ledger_entries
  FOR EACH ROW EXECUTE FUNCTION bs_forbid_mutation();

-- COMMIT anında her grubun borç = alacak olduğunu doğrular.
CREATE OR REPLACE FUNCTION bs_ledger_check_balanced() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  diff bigint;
BEGIN
  SELECT coalesce(sum(debit_minor), 0) - coalesce(sum(credit_minor), 0) INTO diff
  FROM ledger_entries WHERE entry_group = NEW.entry_group;
  IF diff <> 0 THEN
    RAISE EXCEPTION 'Defter grubu % dengesiz (fark % kuruş)', NEW.entry_group, diff
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER ledger_entries_balanced AFTER INSERT ON ledger_entries
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION bs_ledger_check_balanced();

-- MVP'de YALNIZCA çekilemez kampanya kredisi. Nakit bakiye tutmak 6493 sayılı kanun
-- kapsamında e-para lisansı gerektirebilir → bakiye = ledger'dan türetilir, burada önbellek.
CREATE TABLE wallets (
  user_id              uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  promo_balance_minor  bigint NOT NULL DEFAULT 0 CHECK (promo_balance_minor >= 0),
  currency             char(3) NOT NULL DEFAULT 'TRY',
  updated_at           timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- KULLANICI KATKISI
-- =============================================================================
CREATE TABLE favorites (
  user_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  station_id           uuid NOT NULL REFERENCES charging_stations(id) ON DELETE CASCADE,
  created_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, station_id)
);

CREATE TABLE reviews (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  station_id           uuid NOT NULL REFERENCES charging_stations(id) ON DELETE CASCADE,
  transaction_id       uuid REFERENCES transactions(id),   -- dolu = "doğrulanmış şarj" rozeti
  rating               smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body                 text CHECK (length(body) <= 2000),
  is_hidden            boolean NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, station_id)
);

-- "Şu anda buradayım" (14. madde). Manipülasyona karşı: konum, zaman, limit, itibar, seans.
CREATE TABLE checkins (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES users(id),
  station_id           uuid NOT NULL REFERENCES charging_stations(id),
  connector_id         uuid REFERENCES connectors(id),
  kind                 bs_checkin_kind NOT NULL,
  queue_length         smallint CHECK (queue_length BETWEEN 0 AND 30),
  comment              text CHECK (length(comment) <= 500),
  lat                  double precision,
  lng                  double precision,
  distance_m           int,                               -- sunucu hesaplar, istemciye güvenilmez
  transaction_id       uuid REFERENCES transactions(id),  -- seansla doğrulanmış → yüksek ağırlık
  weight               numeric(4,3) NOT NULL DEFAULT 0,   -- skorda kullanılan nihai ağırlık
  accepted             boolean NOT NULL DEFAULT false,
  reject_reason        text,
  created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON checkins (station_id, created_at DESC);
CREATE INDEX ON checkins (user_id, created_at DESC);

-- Arıza olayı (21. madde): OCPP, kullanıcı, operatör ve sistem kaynaklı tek tablo.
CREATE TABLE fault_reports (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  network_id           uuid NOT NULL REFERENCES charging_networks(id),
  station_id           uuid NOT NULL REFERENCES charging_stations(id),
  charge_point_id      uuid REFERENCES charge_points(id),
  connector_id         uuid REFERENCES connectors(id),
  source               text NOT NULL CHECK (source IN ('ocpp', 'user', 'operator', 'system')),
  error_code           text NOT NULL,                     -- ConnectorLockFailure, GroundFailure, STALE_HEARTBEAT ...
  vendor_error_code    text,
  severity             text NOT NULL DEFAULT 'major' CHECK (severity IN ('info', 'minor', 'major', 'critical')),
  status               bs_fault_status NOT NULL DEFAULT 'open',
  diagnosis            jsonb,                             -- kural tabanlı teşhis: nedenler + önerilen aksiyonlar
  auto_actions         jsonb NOT NULL DEFAULT '[]',       -- denenen otomatik aksiyonlar ve sonuçları
  opened_at            timestamptz NOT NULL DEFAULT now(),
  acknowledged_at      timestamptz,
  resolved_at          timestamptz,
  resolved_by          uuid REFERENCES users(id)
);
-- Aynı connector'da aynı hata için tek açık olay (tekrarlayan StatusNotification'lar çoğaltmaz)
CREATE UNIQUE INDEX fault_reports_one_open ON fault_reports
  (station_id, coalesce(connector_id, '00000000-0000-0000-0000-000000000000'::uuid), error_code)
  WHERE status <> 'resolved';

CREATE TABLE support_tickets (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid REFERENCES users(id),
  network_id           uuid REFERENCES charging_networks(id),
  station_id           uuid REFERENCES charging_stations(id),
  connector_id         uuid REFERENCES connectors(id),
  transaction_id       uuid REFERENCES transactions(id),
  fault_report_id      uuid REFERENCES fault_reports(id),
  category             text NOT NULL CHECK (category IN ('not_starting', 'stopped_early', 'payment', 'billing', 'connector_stuck', 'other')),
  status               text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'waiting_user', 'resolved', 'closed')),
  priority             text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  -- 23. madde: istasyon/connector/işlem/ödeme/OCPP durumu/son hata otomatik eklenir
  context_snapshot     jsonb NOT NULL,
  -- [{ "at": "...", "author": "user|agent|system", "text": "..." }]
  thread               jsonb NOT NULL DEFAULT '[]',
  assigned_to          uuid REFERENCES users(id),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON support_tickets (status, priority, created_at);

CREATE TABLE notifications (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid REFERENCES users(id) ON DELETE CASCADE,
  network_id           uuid REFERENCES charging_networks(id),
  channel              text NOT NULL CHECK (channel IN ('push', 'email', 'sms', 'webhook')),
  template             text NOT NULL,
  payload              jsonb NOT NULL DEFAULT '{}',
  dedupe_key           text UNIQUE,                       -- aynı olay için iki bildirim gitmesin
  status               text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'sent', 'failed')),
  sent_at              timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- ALTYAPI: idempotency, domain olayları (outbox), ayarlar, denetim
-- =============================================================================

-- Redis silinse bile (38/13) idempotency korunur → PostgreSQL'de.
CREATE TABLE idempotency_keys (
  scope                text NOT NULL,                     -- 'start_charge', 'payment', 'refund', 'remote_stop'...
  key                  text NOT NULL,
  user_id              uuid,
  request_hash         bytea NOT NULL,                    -- aynı anahtar + farklı gövde = 422
  response_status      smallint,
  response_body        jsonb,
  created_at           timestamptz NOT NULL DEFAULT now(),
  expires_at           timestamptz NOT NULL DEFAULT now() + interval '24 hours',
  PRIMARY KEY (scope, key)
);

-- Transactional outbox: domain olayı iş verisiyle AYNI DB işleminde yazılır,
-- sonra Redis Stream'e yayınlanır. Redis giderse kayıp olmaz (38/13).
CREATE TABLE domain_events (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_type           text NOT NULL,                     -- StationConnected, ChargingStarted ...
  aggregate_type       text NOT NULL,
  aggregate_id         uuid NOT NULL,
  payload              jsonb NOT NULL,
  occurred_at          timestamptz NOT NULL DEFAULT now(),
  published_at         timestamptz
);
CREATE INDEX domain_events_unpublished ON domain_events (id) WHERE published_at IS NULL;
CREATE INDEX ON domain_events (aggregate_type, aggregate_id, id);

CREATE TABLE system_settings (
  key                  text PRIMARY KEY,
  value                jsonb NOT NULL,
  description          text,
  updated_by           uuid REFERENCES users(id),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE audit_logs (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_type           text NOT NULL CHECK (actor_type IN ('user', 'system', 'station', 'operator_api')),
  actor_id             text,
  network_id           uuid,
  action               text NOT NULL,                     -- 'ocpp.remote_stop', 'tariff.publish', 'refund.create'
  subject_type         text,
  subject_id           text,
  ip                   inet,
  user_agent           text,
  before               jsonb,
  after                jsonb,
  created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON audit_logs (subject_type, subject_id, created_at DESC);
CREATE INDEX ON audit_logs (network_id, created_at DESC);
CREATE TRIGGER audit_logs_append_only BEFORE UPDATE OR DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION bs_forbid_mutation();

-- =============================================================================
-- Varsayılan ayarlar (13. ve 41. madde — kodda sabit DEĞİL, buradan yönetilir)
-- =============================================================================
INSERT INTO system_settings (key, value, description) VALUES
('freshness.thresholds_min', '{"live": 5, "recent": 15, "stale": 60}',
 'Son görülme → LIVE (<=live), RECENT (<=recent), STALE (<=stale), üstü UNKNOWN (dakika)'),
('reliability.weights', '{
   "base": 30,
   "ocpp": {"LIVE": 30, "RECENT": 20, "STALE": 0, "UNKNOWN": -30},
   "operator_api_fresh": 15,
   "last_success": [{"within_min": 60, "points": 25}, {"within_min": 360, "points": 18},
                    {"within_min": 1440, "points": 10}, {"within_min": 4320, "points": 3}],
   "checkin_positive_each": 5, "checkin_positive_max": 10,
   "checkin_negative_each": -15, "checkin_negative_max": -30, "checkin_window_min": 120,
   "no_fault_7d": 5, "recent_fault": -20, "contradiction": -20,
   "fault_rate_30d_max_penalty": -15
 }', 'Güven skoru ağırlıkları (açıklanabilir, toplamsal; 0-100 aralığına kırpılır)'),
('reliability.verify_below', '60', 'Skor bunun altındaysa "DİKKAT — doğrulanması gerekiyor"'),
('checkin.rules', '{"max_distance_m": 300, "per_station_cooldown_min": 30, "per_user_daily_max": 20,
                    "min_account_age_hours": 24, "session_verified_weight": 1.5}',
 'Check-in manipülasyon korumaları'),
('payment.preauth_default_minor', '75000', 'Şarj başlangıcında bloke edilecek varsayılan tutar (750,00 TL)'),
('queue.min_samples', '3', 'Bu sayıdan az veri varsa kuyruk tahmini yerine "Yeterli veri yok"');

-- İlk partition'lar
SELECT bs_ensure_monthly_partitions('ocpp_messages', 2);
SELECT bs_ensure_monthly_partitions('transaction_meter_values', 2);
SELECT bs_ensure_monthly_partitions('station_status', 2);
