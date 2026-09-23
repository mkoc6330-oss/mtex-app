# BizimŞarj — Test Stratejisi ve Kesinti Senaryoları

## 1. Test katmanları

| Katman | Araç | Kapsam |
|---|---|---|
| Şema | `scripts/test-schema.sh` (geçici PG16) | DB kısıtları, tetikleyiciler — **mevcut, 19 test geçiyor** |
| Unit | Pest (PHP), `go test`, `flutter test` | Fiyat motoru, güven skoru, durum motoru, OCPP eşlemeleri |
| Integration | Pest + gerçek PG/Redis (docker) | İşlem motoru + ödeme Fake sağlayıcı + outbox |
| API | Pest HTTP + OpenAPI şema doğrulama | Tüm `/api/v1` uçları, yetki matrisi |
| OCPP protokol | Go test + resmi JSON şemaları + simülatör | Her mesaj tipi, hatalı çerçeve, timeout, çevrimdışı kuyruk |
| Ödeme | Fake sağlayıcı (hata enjeksiyonlu) + iyzico sandbox | Provizyon, capture, void, refund, webhook imza, callback kaybı |
| Güvenlik | OWASP ZAP (baseline), `composer audit`, `govulncheck`, yetki testleri | Kiracı izolasyonu, IDOR, brute-force |
| Yük | `simulator/` 1.000 eşzamanlı cihaz + k6 (API) | p99 < 200 ms, sıfır kayıp işlem |
| Senaryo | Aşağıdaki 15 kesinti senaryosu (otomatik) | Beklenen davranış birebir |

## 2. Kesinti senaryoları ve beklenen davranış (38. madde)

| # | Senaryo | Beklenen davranış | Mekanizma |
|---|---|---|---|
| 1 | Telefon interneti kesildi | Şarj **devam eder** (cihaz↔backend bağımsız). Uygulama son bilinen seans durumunu önbellekten gösterir, "Bağlantı yok — son güncelleme 14:32" der; bağlantı gelince WS yeniden abone olur. Durdurma isteği çevrimdışıyken kuyruklanır, bağlantı gelince **aynı idempotency key** ile gönderilir. | Önbellek, idempotency |
| 2 | Şarj cihazı internetsiz kaldı | Heartbeat kesilir → freshness RECENT→STALE→UNKNOWN; haritada ⚫. Devam eden seans cihazda sürer; cihaz geri gelince kuyruktaki MeterValues/StopTransaction işlenir, `was_offline=true`. Kullanıcıya "istasyon bağlantısı koptu, şarjınız cihazda devam ediyor" push'u. | Durum motoru, çevrimdışı işlem |
| 3 | OCPP WebSocket koptu | `StationDisconnected` olayı, `ocpp_connections.disconnected_at`. Cihaz backoff ile yeniden bağlanır; yeniden bağlanınca BootNotification gelmeyebilir → StatusNotification ile durum yenilenir, gerekirse `TriggerMessage(StatusNotification)` gönderilir. | Gateway |
| 4 | Payment callback gelmedi | Ödeme `authorized` bekliyor → 2 dk sonra mutabakat işi sağlayıcıdan `status()` sorgular. Onaylıysa akış devam, değilse `failed`; şarj **başlatılmamıştır** (provizyon-önce-başlat). | Mutabakat |
| 5 | Kullanıcı uygulamayı kapattı | Hiçbir şey olmaz — seans backend'dedir. Açılınca aktif seans ekranı geri gelir. Bitişte push. | Backend durumu |
| 6 | Şarjı başlattı, uygulamadan çıktı | #5 ile aynı + "şarj %80'e ulaştı / bitti / idle ücret 10 dk sonra başlıyor" push'ları. | Bildirim |
| 7 | Charger şarj sırasında offline oldu | #2. Seans "cihazla bağlantı yok" etiketiyle `charging` kalır. 6 saat boyunca haber yoksa seans `charging` durumunda kalır ama otomatik destek kaydı + operatör bildirimi açılır; ücret yalnızca cihazdan gelen gerçek sayaç değeriyle kesinleşir — **tahminle tahsilat yapılmaz**. | İşlem motoru |
| 8 | MeterValue gecikti | Zaman damgasına göre yerleştirilir; `(transaction_id, sampled_at)` PK'sı çiftleri yok sayar. Canlı ekran en son örneği gösterir; fatura yalnızca Stop sayacından. | PK, fatura kuralı |
| 9 | StopTransaction iki kez geldi | İkincisi UNIQUE `(charge_point_id, ocpp_transaction_id)` ile eşleşir, işlem zaten `completed` → hiçbir şey değişmez, cihaza yine `.conf` döner (kuyruğu boşalsın). Tek capture. | DB kısıtı, idempotent capture |
| 10 | Kullanıcı ödedi, charger başlamadı | RemoteStart `Rejected`/timeout veya 90 sn içinde `TransactionStarted` gelmedi → işlem `failed`, provizyon **void** (iade değil, bloke kaldırma), kullanıcıya "Şarj başlamadı, ödemeniz iptal edildi" + alternatif istasyonlar; arıza sayacına +1. | İşlem motoru, void |
| 11 | Charger başladı, ödeme başarısız oldu | Tasarım gereği ödeme **önce** onaylanır; bu yalnızca capture aşamasında olabilir (ör. provizyon süresi doldu). Durum: işlem `completed`, ödeme `failed` + `needs_reconciliation`. Kullanıcıdan borç tahsili (kayıtlı kartla yeniden deneme 3×), başarısızsa hesap yeni seansa kapatılır ve destek kaydı. Provizyon süresi (ör. 7 gün) seans süresinden çok uzun tutulur. | Ayrı durumlar, mutabakat |
| 12 | Server yeniden başladı | Tüm durum PG'de. Gateway ayağa kalkınca cihazlar yeniden bağlanır; outbox'ta yayımlanmamış olaylar yayımlanır; bekleyen komutlar düşer (Laravel `Timeout` görür, idempotent tekrar dener). Kuyruk işleri Redis'ten devam eder. | Outbox, durumsuz servis |
| 13 | Redis silindi | Veri kaybı yok: idempotency ve olaylar PG'de. Anlık durum önbelleği `connectors`/`charging_stations` tablolarından yeniden kurulur (başlangıç işi); rate-limit sayaçları sıfırlanır (kabul edilebilir); kuyruktaki işler outbox'tan yeniden üretilir. | PG tek doğruluk kaynağı |
| 14 | PostgreSQL bağlantısı kesildi | API 503 + `Retry-After`; mobil önbellekten okur. Gateway gelen OCPP mesajlarını **onaylamaz** (CALLERROR InternalError) → cihaz kendi kuyruğunda tutup tekrar gönderir; böylece işlem verisi kaybolmaz. Heartbeat'ler bellekte cevaplanır. Uptime Kuma alarmı. | Gateway geri basıncı |
| 15 | İki kullanıcı aynı connector için start istedi | İlk gelen kısmi UNIQUE index'i alır; ikincisi 409 `CONNECTOR_BUSY`, provizyon **alınmadan** reddedilir (index kontrolü ödemeden önce). | DB kısıtı (test T1) |

## 3. Gerçek cihaz testi (45. madde)
1 adet OCPP 1.6 + 1 adet OCPP 2.0.1 cihazla, her biri için: Boot · Heartbeat · Authorize · Start · MeterValues · Stop · RemoteStop · Fault (connector kilidi/kablo simülasyonu) · Reset · Reconnect (modem/ethernet çekme). Her adımın ham OCPP log'u ve ekran görüntüsü `tests/field/<cihaz-model>/` altına kaydedilir; bu kayıt yeni cihaz modelleri için referans olur.

## 4. Çalıştırma
```bash
bizimsarj/scripts/test-schema.sh          # Faz 2 — şimdi çalışır
# Faz 3+: docker compose run --rm backend php artisan test
#         cd ocpp-gateway && go test ./...
#         cd simulator && go run . -n 1000 -url wss://localhost/ocpp/1.6
```
