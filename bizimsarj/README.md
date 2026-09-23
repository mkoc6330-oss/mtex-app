# BizimŞarj

Elektrikli araç şarj platformu — **"Gitmeden önce istasyonun gerçekten kullanılabilir olduğunu bil."**

Harita + gerçek durum + güven skoru + fiyat şeffaflığı + tek uygulamadan şarj/ödeme + arıza ve destek yönetimi.
İlk hedef: **10 gerçek cihaz**, gerçek kullanıcıya güvenilir şarj başlatma ve ücretlendirme. Mimari 100 → 1.000 → 10.000 cihaza büyür, ama ilk gün 1.000 cihazın maliyetini ödemez.

## Durum

| Faz | | |
|---|---|---|
| 1 — Mimari | ✅ | `docs/` |
| 2 — Veritabanı şeması | ✅ | `database/schema.sql` — PG16'da 19 test geçiyor |
| 3 — Laravel iskeleti | ⏭ sıradaki | |

## İstenen 13 teslimat → dosya

| # | Teslimat | Yer |
|---|---|---|
| 1 | Nihai mimari diyagramı | [ARCHITECTURE.md §1](docs/ARCHITECTURE.md#1-nihai-mimari-diyagramı) |
| 2 | Veritabanı ERD | [DATABASE.md](docs/DATABASE.md) |
| 3 | Klasör yapısı | [ARCHITECTURE.md §2](docs/ARCHITECTURE.md#2-klasör-yapısı) |
| 4 | API listesi | [API.md](docs/API.md) |
| 5 | OCPP mimarisi | [OCPP.md](docs/OCPP.md) |
| 6 | Güvenlik mimarisi | [SECURITY.md](docs/SECURITY.md) |
| 7 | MVP özellik listesi | [PRODUCT.md §1](docs/PRODUCT.md#1-mvp-özellik-listesi) |
| 8 | Geliştirme fazları | [ROADMAP.md §1](docs/ROADMAP.md) |
| 9 | Aylık altyapı maliyeti | [COST.md §2](docs/COST.md#2-aylık-altyapı--üçüncü-taraf-aşama-1) |
| 10 | 10 / 100 / 1.000 / 10.000 ölçek maliyeti | [COST.md §3](docs/COST.md#3-ölçek-maliyeti-aylık-ödeme-komisyonu-hariç) |
| 11 | Şikâyet → çözüm matrisi | [PRODUCT.md §2](docs/PRODUCT.md) |
| 12 | Risk listesi | [RISKS.md](docs/RISKS.md) |
| 13 | 90 günlük yol haritası | [ROADMAP.md §2](docs/ROADMAP.md#2-90-günlük-yol-haritası) |

Ek: kesinti senaryoları ve test stratejisi → [TESTING.md](docs/TESTING.md).
`DEPLOYMENT.md` ve `TROUBLESHOOTING.md` ilgili fazlarda (3 ve 18–20) gerçek komutlarla yazılacak — içeriksiz taslak eklenmedi.

## Hızlı başlangıç (şu an)

```bash
bizimsarj/scripts/test-schema.sh     # geçici PostgreSQL 16 açar, şema + seed + testler
```

## Stack
Flutter · Laravel 11 (PHP 8.3) + Filament · Go (OCPP gateway) · PostgreSQL 16 · Redis 7 · Nginx · Docker Compose · Cloudflare (ücretsiz) · FCM.
