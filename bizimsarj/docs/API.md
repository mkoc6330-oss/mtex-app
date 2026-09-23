# BizimŞarj — API Listesi

- Temel: `https://api.bizimsarj.com/api/v1` · Gerçek zamanlı: `wss://api.bizimsarj.com/ws` · OCPP: bkz. [OCPP.md](OCPP.md)
- Kimlik: `Authorization: Bearer <access JWT, 15 dk>` + refresh token (30 gün, rotasyonlu)
- Para yaratan / cihaza komut gönderen tüm POST'larda **`Idempotency-Key` başlığı zorunlu** (yoksa 400).
- Hata biçimi: `{ "error": { "code": "CONNECTOR_BUSY", "message": "...", "details": {} } }`
- OpenAPI: `backend/openapi/openapi.yaml` (Faz 3'te üretilir, Swagger UI `/api/docs`, yalnızca staging'de açık)

## Kimlik (Faz 4)
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/auth/otp/request` | Telefon (E.164, yabancı dahil) veya e-posta'ya kod |
| POST | `/auth/otp/verify` | Kod → access + refresh |
| POST | `/auth/email/magic-link` | SMS alamayan (yabancı) kullanıcı için alternatif |
| POST | `/auth/refresh` | Refresh token rotasyonu (eski token tekrar kullanılırsa aile iptal) |
| POST | `/auth/logout` | Aileyi iptal et |
| GET/PATCH/DELETE | `/me` | Profil; DELETE = KVKK silme talebi |
| GET/POST/DELETE | `/me/vehicles` · `/me/vehicles/{id}` | Araçlar |
| GET | `/vehicle-models?q=` | Araç modeli arama |

## İstasyonlar (Faz 5, 10, 11)
| Metot | Yol | Açıklama |
|---|---|---|
| GET | `/stations?lat=&lng=&radius_m=&bbox=&current=AC,DC,HPC&connector=CCS2&min_kw=&max_price=&available_only=&sort=best\|cheapest\|reliable\|fastest\|distance` | Harita/liste. Her öğe: fiyat, müsait/toplam connector, **display_state, freshness, güven skoru, son doğrulama, son başarılı şarj**, mesafe |
| GET | `/stations/{id}` | Detay: EVSE/connector'lar, tarifeler, ilan edilen vs gerçek güç, son hata, güven açıklaması, sıra tahmini |
| GET | `/stations/{id}/reliability` | Faktör bazlı açıklama |
| GET | `/stations/{id}/reviews` | Yorumlar ("doğrulanmış şarj" rozeti) |
| GET | `/qr/{code}` | QR'dan EVSE/connector çözümle |
| POST | `/quotes` | `{connector_id, vehicle_id?, soc_from, soc_to}` → kWh, süre aralığı, TL aralığı, kalemler, varsayımlar |
| POST | `/recommendations` | `{lat,lng, vehicle_id, soc, mode}` → sıralı liste + **neden** açıklaması |
| POST | `/routes/plan` | `{origin, destination, vehicle_id, soc_now, soc_arrival_min}` → önerilen duraklar |

## Şarj (Faz 8, 12)
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/charging-sessions` | **Idempotent.** `{connector_id, payment_method_id, quote_id}` → provizyon + RemoteStart. 409 `CONNECTOR_BUSY` |
| GET | `/charging-sessions/{id}` | Anlık: durum, kWh, güç, süre, tahmini TL |
| POST | `/charging-sessions/{id}/stop` | **Idempotent.** RemoteStop |
| GET | `/me/charging-sessions` | Geçmiş |
| GET | `/charging-sessions/{id}/receipt` | Makbuz / e-Arşiv fatura bağlantısı |
| WS | `/ws` kanal `session.{id}` | `ChargingMeterUpdated`, `ChargingStopped`, `PaymentCaptured` |
| WS | `/ws` kanal `stations.bbox.{geohash}` | Haritadaki pin değişimleri |

## Ödeme (Faz 13)
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/payment-methods` | Sağlayıcının 3DS/kart saklama akışını başlatır (kart numarası bize gelmez) |
| GET/DELETE | `/payment-methods` · `/{id}` | |
| POST | `/webhooks/payments/{provider}` | **İmza doğrulamalı**, idempotent, CSRF'siz, rate-limit'li |

## Kullanıcı katkısı (Faz 15)
| Metot | Yol | Açıklama |
|---|---|---|
| POST | `/stations/{id}/checkins` | `{kind, connector_id?, queue_length?, lat, lng}` → sunucu mesafe/limit/itibar kontrolü |
| POST | `/stations/{id}/reviews` | |
| GET/PUT/DELETE | `/me/favorites/{station_id}` | |
| POST | `/support/tickets` | `{category, session_id?, station_id?}` → bağlam **otomatik** eklenir, kullanıcıya bulunan hata mesajı döner |
| GET | `/support/tickets/{id}` · POST `/support/tickets/{id}/messages` | |

## Operatör (Faz 17) — `/operator/*`, `network_members` rolüne göre
| Metot | Yol | Açıklama |
|---|---|---|
| GET | `/operator/stations` · `/operator/stations/{id}` | Yalnızca kendi ağının |
| GET | `/operator/sessions?status=active` | Aktif şarjlar |
| GET | `/operator/faults` · PATCH `/operator/faults/{id}` | Arıza onay/çözüm |
| POST | `/operator/charge-points/{id}/commands` | **Idempotent.** `reset`, `unlock`, `stop`, `start`, `availability`, `diagnostics` — rol: manager/technician; audit log'a yazılır |
| GET/POST | `/operator/tariffs` | Yeni sürüm tarife (eskisi değişmez) |
| GET | `/operator/reports/revenue?from=&to=` · `/operator/reports/energy` | |
| POST | `/operator/charge-points` | Cihaz kaydı → tek seferlik Basic Auth parolası üretir |

## Admin (Faz 16) — `/admin/*`, rol `admin`/`support`
İstasyon/ağ/kullanıcı yönetimi, ödeme ve iade (`POST /admin/refunds`, idempotent), destek kuyruğu, OCPP bağlantı ve mesaj izleyici, audit log arama, `system_settings` düzenleme. Panel arayüzü Filament; aynı domain servislerini çağırır.

## İç (dışarıya kapalı)
| Yol | Kim |
|---|---|
| `POST ocpp-gateway:8081/internal/commands` | Laravel → Gateway (HMAC) |
| `GET /internal/health` | Uptime Kuma |
| `GET /internal/metrics` | Prometheus (Aşama 2+) |
