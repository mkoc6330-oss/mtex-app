# BizimŞarj — OCPP Mimarisi

## 1. Uç noktalar ve bağlantı

| Sürüm | URL | Subprotocol |
|---|---|---|
| OCPP 1.6J | `wss://ocpp.bizimsarj.com/ocpp/1.6/{chargePointId}` | `ocpp1.6` |
| OCPP 2.0.1 | `wss://ocpp.bizimsarj.com/ocpp/2.0.1/{chargePointId}` | `ocpp2.0.1` |

- `ocpp.` alt alan adı **Cloudflare proxy'si kapalı (DNS-only)** çalışır: mTLS istemci sertifikası Cloudflare'dan geçmez ve bazı cihazlar Cloudflare'ın TLS profilinde sorun çıkarır. TLS'i Nginx (Let's Encrypt) sonlandırır ve gateway'e iç ağdan iletir.
- URL'deki sürüm ile müzakere edilen subprotocol eşleşmezse bağlantı reddedilir.
- `chargePointId` kayıtlı değilse, `registration_status=Rejected` ise veya kimlik bilgisi yanlışsa WebSocket yükseltmesi **HTTP 401** ile reddedilir (bağlantı hiç açılmaz).
- Aynı kimlikle ikinci bağlantı gelirse eskisi kapatılır (`ocpp_connections_one_open` index'i).
- WebSocket ping 60 sn; 3 ping kaçarsa bağlantı ölü sayılır → `StationDisconnected`.

## 2. Katmanlar

```
transport  → TLS, subprotocol, auth, bağlantı başına rate limit, ping/pong
rpc        → [2,id,action,payload] / [3,id,payload] / [4,id,code,desc,details]
             bekleyen çağrı tablosu (uniqueId → kanal), 30 sn timeout,
             cihaz başına aynı anda tek giden CALL (spesifikasyon gereği)
v16 / v201 → JSON Schema doğrulama (resmi OCA şemaları), sürüme özel eşleme
common     → ortak domain modeli + olaylar; komutları sürüme göre çevirir
outbox     → olayı PG'ye (domain_events + ilgili tablolar) tek işlemde yazar,
             sonra Redis Stream'e duyurur
rawlog     → her çerçeve JSONL'e (zstd, günlük rotasyon, 30 gün)
```

## 3. İlk sürümde desteklenen mesajlar

| Yetenek | OCPP 1.6J | OCPP 2.0.1 | Ortak olay / komut |
|---|---|---|---|
| Kayıt | BootNotification | BootNotification | `StationBooted` |
| Canlılık | Heartbeat | Heartbeat | `last_seen_at` güncelle |
| Durum | StatusNotification | StatusNotification | `ConnectorStatusChanged` |
| Hata olayı | StatusNotification(errorCode) | NotifyEvent | `StationFaulted` |
| Yetki | Authorize | Authorize | `AuthorizeRequested` → Laravel karar verir |
| İşlem başladı | StartTransaction | TransactionEvent(Started) | `TransactionStarted` |
| Ölçüm | MeterValues | TransactionEvent(Updated) / MeterValues | `MeterSampled` |
| İşlem bitti | StopTransaction | TransactionEvent(Ended) | `TransactionEnded` |
| Uzaktan başlat | RemoteStartTransaction | RequestStartTransaction | `cmd.start` |
| Uzaktan durdur | RemoteStopTransaction | RequestStopTransaction | `cmd.stop` |
| Kilit aç | UnlockConnector | UnlockConnector | `cmd.unlock` |
| Reset | Reset (Soft/Hard) | Reset (OnIdle/Immediate) | `cmd.reset` |
| Teşhis | GetDiagnostics + DiagnosticsStatusNotification | GetLog + LogStatusNotification | `cmd.diagnostics` |
| Müsaitlik | ChangeAvailability | ChangeAvailability | `cmd.availability` |
| Yapılandırma | GetConfiguration / ChangeConfiguration | GetVariables / SetVariables | `cmd.config.get/set` |

**Kapsam dışı (MVP):** Smart Charging profilleri, rezervasyon, yerel yetki listesi, firmware güncelleme, ISO 15118 Plug & Charge, Display/Tariff mesajları. Veri modeli bunları engellemez.

## 4. Kritik eşlemeler

- **1.6 connectorId 0** = cihazın tamamı. `StatusNotification(connectorId=0, Faulted)` → tüm EVSE'ler etkilenir.
- **1.6 durumları** (`Available, Preparing, Charging, SuspendedEV, SuspendedEVSE, Finishing, Reserved, Unavailable, Faulted`) ve **2.0.1 durumları** (`Available, Occupied, Reserved, Unavailable, Faulted`) ortak `bs_connector_status` enum'una eşlenir; 2.0.1 `Occupied` alt durumu TransactionEvent'in `chargingState`'inden türetilir.
- **transactionId:** 1.6'da `StartTransaction.conf` ile **biz veririz** (PG sequence, int32 sınırında). 2.0.1'de istasyon verir. Domain işlem kendi UUID'sini taşır; eşleme `transactions.ocpp_transaction_id`.
- **idTag / idToken:** Uygulamadan başlatmada her seansa tek kullanımlık, 20 karakter (1.6 idTag sınırı) rastgele token üretilir; `Authorize` geldiğinde Laravel bu token'ın açık, ödemesi onaylı bir işleme ait olduğunu doğrular.
- **Çevrimdışı işlemler:** Cihaz bağlantısızken biten işlemi kuyruklayıp sonradan gönderir. `timestamp` alanı esas alınır, `was_offline=true` işaretlenir, UNIQUE index sayesinde tekrarlar yok sayılır ve **yine** `.conf` döndürülür (cihaz kuyruğunu boşaltabilsin).

## 5. Komut akışı (Laravel → cihaz)

```
POST http://ocpp-gateway:8081/internal/commands        (yalnızca iç ağ + paylaşılan HMAC anahtarı)
{ "idempotency_key": "stop:tx-uuid", "charge_point": "BS-TEST-DC-01",
  "command": "stop", "args": { "transaction_id": "1001" }, "timeout_s": 30 }

→ 200 { "status": "Accepted" | "Rejected" | "Timeout" | "Offline", "raw": {...} }
```

- Aynı `idempotency_key` 24 saat içinde tekrar gelirse komut **tekrar gönderilmez**, ilk sonuç döner (Redis + PG).
- Cihaz çevrimdışıysa `Offline` döner, komut kuyruklanmaz (bayat komut tehlikelidir); karar Laravel'de.
- Aşama 3'te: bağlantı hangi düğümdeyse (`cp:{id}:node` Redis anahtarı) komut o düğüme Redis pub/sub ile iletilir.

## 6. Güvenlik (9. madde)

| Önlem | Uygulama |
|---|---|
| TLS | Zorunlu (TLS 1.2+). `ws://` üretimde kapalı. TLS desteklemeyen eski cihaz → WireGuard/özel APN üzerinden, asla açık internetten düz metin değil. |
| İstasyon kimlik doğrulama | Güvenlik Profili 2 (TLS + HTTP Basic, parola argon2id hash) varsayılan; Profil 3 (mTLS) için `client_cert_sha256` alanı ve sertifika yaşam döngüsü hazır. |
| chargePointId kontrolü | Regex (`^[A-Za-z0-9._:-]{1,48}$`), kayıtlı olmalı, URL kimliği = Basic Auth kullanıcı adı. |
| Replay | Cihaz başına son N `uniqueId` Redis'te (10 dk); aynı CALL tekrar gelirse işlenmez, önbellekteki yanıt döner. Zaman damgası sunucu saatinden ±15 dk sapıyorsa işaretlenir (çevrimdışı kuyruk hariç). |
| Rate limiting | Cihaz başına 20 mesaj/sn tavan, IP başına bağlantı denemesi 10/dk; başarısız auth → artan bekleme. |
| IP allowlist | Opsiyonel, `charge_points.ip_allowlist` (CIDR dizisi). |
| Ayrı log | Ham OCPP log'u uygulama log'undan ayrı dosya/akış; `ocpp_connections` + `ocpp_messages` + `audit_logs` ile bağlanma, kopma, heartbeat, hata, işlem, komut ve yanıt izlenir. |

## 7. Simülatör ve yük testi (44. madde)

`simulator/` (Go): N sanal cihaz, her biri Boot → Heartbeat → StatusNotification → rastgele seans (Start → MeterValues/60 sn → Stop), rastgele kopma/yeniden bağlanma, hata enjeksiyonu. Hedef: **1.000 eşzamanlı cihaz, p99 yanıt < 200 ms, sıfır kayıp işlem**. Resmi uyumluluk için ayrıca OCA OCTT (ücretli) yerine açık kaynak araçlar + gerçek cihaz testi (45. madde, [TESTING.md](TESTING.md)).
