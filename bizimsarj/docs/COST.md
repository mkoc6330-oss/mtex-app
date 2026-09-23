# BizimŞarj — Maliyet Raporu

> **Kur varsayımı (Eylül 2026):** 1 EUR ≈ 48 TL, 1 USD ≈ 41 TL. Sunucu fiyatları KDV hariç liste fiyatlarıdır.
> **Tüm üçüncü taraf fiyatları ve ücretsiz kotalar sağlayıcıların değiştirebileceği değerlerdir — satın almadan önce güncel fiyat sayfasından doğrulanmalı.** Burada gizlenen maliyet yok; en büyük kalem altyapı değil **ödeme komisyonu ve e-fatura**.

## 1. Aşama 1 varsayımları (10 cihaz)

| Varsayım | Değer |
|---|---|
| Şarj cihazı | 10 (≈6 DC, 4 AC), toplam ~20 connector |
| Seans | cihaz başına günde ~5 → **~1.500 seans/ay** |
| Ortalama seans | 30 kWh × ~10 TL = **~300 TL** → aylık ciro (GMV) ~450.000 TL |
| Aktif kullanıcı | ~300–500 |
| API trafiği | ~2–3 milyon istek/ay (harita + canlı seans), < 50 GB çıkış |
| OCPP trafiği | 10 cihaz × (heartbeat 5 dk + MeterValues 60 sn seans içinde) ≈ 0,5 mesaj/sn |

## 2. Aylık altyapı + üçüncü taraf (Aşama 1)

| Kalem | Hizmet | Aylık TL | Ücretsiz limit / not |
|---|---|---|---|
| **Infrastructure** | 1 VPS 4 vCPU / 8 GB / 80 GB (Hetzner CX32 sınıfı, ~€8) | ~400 | Türkiye'de eşdeğer VPS: ~800–1.200 TL (KVKK yurt dışı aktarım gerekmez) |
| **Storage (yedek)** | Backblaze B2 veya Hetzner Storage Box | 10–200 | B2: ilk 10 GB ücretsiz, sonrası ~$6/TB·ay |
| Alan adı | bizimsarj.com + .com.tr | ~60 | |
| DNS / SSL / CDN / WAF | Cloudflare Free + Let's Encrypt | 0 | CF Free: sınırsız DNS/CDN trafiği, temel WAF kuralları; LE: sınırsız, 90 günlük sertifika |
| **Monitoring** | Uptime Kuma (kendi sunucumuzda) + Sentry Developer | 0 | Sentry Developer: 5.000 hata/ay, 1 kullanıcı |
| Loglar | Dosya + logrotate | 0 | Loki Aşama 2'de, yine kendi sunucumuzda |
| Push | Firebase Cloud Messaging | 0 | FCM gönderimi ücretsiz, pratik limit yok |
| E-posta | Brevo Free | 0 | 300 e-posta/gün |
| **SMS** | Netgsm / İleti Merkezi OTP | 150–250 | ~500–800 SMS × ~0,20–0,30 TL. Yabancı numara SMS'i 5–10× pahalı → e-posta alternatifi |
| **Map** | Google Maps SDK (Android/iOS) harita gösterimi | 0 | Mobil yerel dinamik harita ücretsiz. **Places/Geocoding kullanılmaz** (istasyon verisi bizde) |
| Rota | OpenRouteService | 0 | 2.000 rota/gün, 40/dk. Aşılırsa Google Routes (aylık 10.000 ücretsiz, sonra ~$5/1.000) |
| e-Arşiv fatura | Özel entegratör (kontör) | 400–700 | ~1.500 fatura × 0,10–0,30 TL + yıllık paket |
| Apple Developer | $99/yıl | 0 / ~340 | MTEX'in mevcut hesabından yayınlanırsa ek maliyet yok; ayrı şirket hesabıysa ~340 TL/ay |
| Google Play | $25 tek sefer | 0 | |
| **TOPLAM (sabit)** | | **≈ 1.100–1.600 TL** (Hetzner) · **≈ 1.600–2.400 TL** (TR VPS) | ✅ 1.000–3.000 TL hedefi içinde |

### Payment Cost (değişken — altyapı bütçesine dahil DEĞİL)
| Kalem | Varsayım | Aylık |
|---|---|---|
| Sanal POS / iyzico / PayTR komisyonu | %2,5–3,5 + işlem başı ~0,25 TL (anlaşmaya bağlı) | 450.000 TL ciro → **~11.000–16.000 TL** |
| Provizyon + capture | Çoğu sağlayıcıda tek işlem gibi ücretlenir; void ücretsiz | — |
| İade | Komisyon genelde geri verilmez | ciroya bağlı |

> Bu, sistemin **en büyük tek maliyeti**. Fiyatlandırmaya (platform komisyonu `commission_bps`) mutlaka yansıtılmalı. Pazaryeri (alt üye işyeri) ödeme ürünü kullanılırsa oran biraz daha yüksek olabilir ama operatöre ödeme (payout) otomatikleşir ve lisans riski azalır (RISKS.md).

## 3. Ölçek maliyeti (aylık, ödeme komisyonu hariç)

| | **10 cihaz** | **100 cihaz** | **1.000 cihaz** | **10.000 cihaz** |
|---|---|---|---|---|
| Seans/ay | 1.500 | 15.000 | 150.000 | 1.500.000 |
| Aktif kullanıcı | ~400 | ~4.000 | ~40.000 | ~400.000 |
| Sunucu topolojisi | 1 VPS | API + Gateway + DB (3 VPS) | LB, 2× API, 2× GW, PG primary+replica, Redis, monitoring | Adanmış sunucular, 4+ API, 4+ GW, PG + 2 replica + partition |
| Infrastructure | ~400 | ~1.500 | ~9.000 | ~30.000–40.000 |
| Storage (yedek) | ~10 | ~200 | ~500 | ~2.000 |
| Monitoring / log | 0 | ~1.100 (Sentry Team) | ~2.500 | ~10.000 |
| SMS | ~200 | ~1.000 | ~8.000 | ~25.000 |
| Map / rota | 0 | 0–1.000 | ~8.000 | ~20.000–40.000 |
| e-Arşiv | ~550 | ~3.500 | ~9.000* | ~60.000–90.000* |
| **Toplam** | **~1.200–1.600 TL** | **~7.000–9.000 TL** | **~35.000–45.000 TL** | **~150.000–200.000 TL** |
| Cihaz başına | ~140 TL | ~80 TL | ~40 TL | ~17 TL |

\* 1.000+ cihazda seans başına fatura yerine **haftalık toplu fatura** (VUK 7 gün kuralı içinde — mali müşavir onayı gerekir) varsayılmıştır; seans başı fatura bu kalemi ~3× yapar.

## 4. Tek seferlik / geliştirme maliyetleri (varsayımsal)

| Kalem | Tahmin | Varsayım |
|---|---|---|
| **Development Cost** — 90 gün MVP | ~650.000–950.000 TL | 1 kıdemli backend (Laravel + Go) tam zamanlı + 1 Flutter yarı zamanlı, Claude destekli; TR 2026 işveren maliyeti kıdemli ~150–220 bin TL/ay |
| Test cihazı — OCPP 1.6 AC 22 kW | ~25.000–40.000 TL | Ağa bağlanabilen, OCPP URL'si değiştirilebilen wallbox |
| Test cihazı — OCPP 2.0.1 AC | ~40.000–70.000 TL | 2.0.1 sertifikalı model; DC testi partner sahada yapılır (DC cihaz 500 bin TL+) |
| Hukuk (EPDK, KVKK, ödeme modeli, sözleşmeler) | ~50.000–150.000 TL | Tek seferlik danışmanlık |
| Sızma testi (canlıya çıkmadan) | ~40.000–100.000 TL | Aşama 2'de; MVP'de otomatik tarama (ZAP) ücretsiz |
| Cihaz SIM kartları | ~100–200 TL/cihaz/ay | Genelde operatör öder; kendi cihazımızsa bizde |

## 5. Maliyet kontrolü kuralları

1. Aşama değiştirmeden önce ölçüt: CPU > %60 (15 dk ortalama) veya PG bağlantı/IO doygunluğu — hisle değil metrikle.
2. Ücretli servis eklemeden önce kendi sunucumuzda açık kaynak alternatif denenir (Uptime Kuma, GlitchTip, Loki, Grafana).
3. Harita API'si yalnızca rota için; arama/geocoding kendi veritabanımızdan.
4. SMS yalnızca OTP; bildirimler push.
5. Her ay bu tablo gerçekleşen faturalarla güncellenir.
