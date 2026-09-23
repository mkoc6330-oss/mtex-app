# BizimŞarj — MVP Özellikleri ve Şikâyet → Çözüm Matrisi

## 1. MVP özellik listesi

**MVP tanımı:** 10 gerçek cihaz bağlı; gerçek kullanıcı uygulamadan istasyonu bulur, fiyatı görür, ödeme yapar, şarjı başlatır/izler/bitirir ve makbuzunu alır. Her istasyonun "gerçekten çalışıyor mu" bilgisi doğrudur.

### Mobil (Flutter)
| # | Özellik | MVP | Sonra |
|---|---|---|---|
| 1 | Harita + liste, yakındaki istasyonlar | ✅ | |
| 2 | Filtre: AC/DC/HPC, soket, min kW, fiyat, yalnızca müsait | ✅ | |
| 3 | Pin'de **gerçek durum** (🟢🟡🔵🔴⚫) + güven skoru + son doğrulama | ✅ | |
| 4 | Sıralama: En uygun / En ucuz / En güvenilir / En hızlı + "neden?" | ✅ | |
| 5 | İstasyon detayı: connector'lar, fiyat kalemleri, ilan edilen vs gerçek güç, son başarılı şarj, son hata | ✅ | |
| 6 | Maliyet tahmini (%20→%80, araç modeline göre) | ✅ basit model | araç şarj eğrisi DB |
| 7 | QR ile / "Şarjı Başlat" ile başlatma | ✅ | |
| 8 | Kartla ödeme (provizyon + kesin tutar) | ✅ | cüzdan, ad-hoc terminal |
| 9 | Canlı seans ekranı (kWh, kW, süre, TL) + durdurma | ✅ | |
| 10 | Makbuz + e-Arşiv fatura | ✅ | |
| 11 | Check-in ("Şu anda buradayım") | ✅ | |
| 12 | "Şarj başlamadı" → otomatik bağlamlı destek kaydı | ✅ | canlı sohbet |
| 13 | Favoriler, son istasyonlar, son seans **çevrimdışı önbellek** | ✅ | |
| 14 | Push: seans bitti, idle ücret başlayacak, favori istasyon arızalı | ✅ | |
| 15 | Rota planlama + durak önerisi | 🟡 basit (≤3 durak) | trafik, yükseklik, hava |
| 16 | Sıra/yoğunluk tahmini (veri yetersizse "Yeterli veri yok") | 🟡 | |
| 17 | Yorum/puan | 🟡 | |
| 18 | Giriş: telefon OTP (yabancı dahil) + e-posta | ✅ | Apple/Google |
| — | Rezervasyon, Plug&Charge, AI asistan | | ❌ |

### Backend
OCPP 1.6J + 2.0.1 gateway, durum motoru, güven skoru, fiyat motoru, işlem motoru, ödeme soyutlaması + mutabakat, defter, arıza yönetimi (kural tabanlı), check-in koruması, idempotency, outbox olayları, audit log.

### Paneller (Filament)
- **Admin:** dashboard, istasyonlar, canlı harita, OCPP bağlantıları + mesaj izleyici, aktif şarjlar, arızalar, ödemeler/iadeler, kullanıcılar, destek, tarifeler, raporlar, komisyonlar, audit log, ayarlar.
- **Operatör:** kendi cihazlarının online/offline durumu, aktif şarj, gelir, hata, connector durumu, enerji, fiyat yönetimi, kullanıcı raporları, uzaktan komutlar (Start/Stop/Unlock/Reset/Teşhis).

## 2. Forum/kullanıcı şikâyeti → ürün çözümü matrisi

| Şikâyet | Kök neden | BizimŞarj çözümü | Nerede | Başarı ölçütü |
|---|---|---|---|---|
| "Uygulama müsait diyor ama cihaz çalışmıyor" | Tek sinyal (API `available=true`) | Güven skoru + `last_seen` tazeliği + canlı OCPP + check-in + çelişki tespiti; güven <60 → 🟡 "doğrulanması gerekiyor" | Durum motoru, Reliability | 🟢 gösterilen istasyonda başarısız başlatma oranı < %3 |
| "Her ağ için ayrı uygulama" | Kapalı ekosistemler | `OperatorConnector` (OCPP · OCPI · PartnerAPI), OCPI'ye hazır veri modeli | Integration | Aşama 2'de ≥1 partner ağ |
| "Ödeme çalışmıyor" | Tek sağlayıcı, callback kaybı | Sağlayıcı soyutlaması + yedek sağlayıcı + mutabakat işi + QR; ileride ad-hoc terminal | Payments | Ödemeye takılan başlatma < %1; callback kaybında 10 dk içinde düzeltme |
| "İstasyon haritada görünmüyor" | Eksik/kopya veri | Veri alımı + tekilleştirme (`network_id, external_ref` + 30 m yakınlık) + operatör beslemesi + kullanıcı önerisi | Stations | Bölgedeki bilinen istasyonların kapsaması |
| "240 kW yazıyor 50 kW veriyor" | Yalnızca ilan edilen güç | İlan edilen / anlık / son 20 seans ortalama / tepe güç ayrı; "Son 20 seansta ortalama 86 kW" | EVSE istatistikleri | Her DC istasyonda gerçek güç verisi |
| "Cihaz bozuk ama uygulama göstermiyor" | Heartbeat/hata izlenmiyor | Fault olayı + heartbeat + stale tespiti + kullanıcı raporu → dakikalar içinde 🔴/⚫ | Durum motoru, Faults | Arıza → haritaya yansıma < 2 dk |
| "Destek hiçbir şey yapmıyor" | Destek cihazı göremiyor | Destek panelinde bağlamlı kayıt + yetkili kişiye Remote Stop/Start, Unlock, Reset, Teşhis | Support, Operatör paneli | İlk yanıt < 15 dk, uzaktan çözülen kayıt oranı |
| "Yabancıyım, SMS gelmiyor" | Yalnızca TR telefon | E.164 uluslararası + e-posta magic link; ileride ad-hoc ödeme | Identity | Yabancı kullanıcı giriş başarısı |
| "Fiyatı önceden bilmiyorum" | Gizli kalemler | Başlamadan tüm kalemler (kWh, başlangıç, dakika, idle, park, min ücret, KDV, kampanya) + TL aralığı tahmini; fiyat seans başında dondurulur | Pricing | Tahmin vs gerçek sapma < %15 |
| "Fişi çıkaramıyorum / kilitli kaldı" | Kilit arızası | Uygulamada "Kilidi aç" → UnlockConnector (yetkili akış) + ConnectorLockFailure kuralı | OCPP, Faults | Kilit kayıtlarının uzaktan çözümü |
| "Şarj bitti ama ücret işlemeye devam etti" | Idle fee bilinmiyor | Şarj bitince push + idle başlama geri sayımı | Notifications | İdle ücret şikâyeti |
| "İki kere ücret kesildi" | Tekrarlanan istek | Idempotency + defter + tek aktif işlem kısıtı + mutabakat | Payments, DB | Çift tahsilat = 0 |
