# MTEX Hurda — Proje Rehberi

Hurda/çelik/emtia fiyat uygulaması (Flutter, iOS + Android). Sahibi: ERKOÇ HURDA GERİ DÖNÜŞÜM (Mehmet Doğan Koç). Türkçe konuş.

## Mimari
- **Backend:** https://metalexchange.io/api/v1 — hazır ve canlı, uygulamada elle veri yok. Uçlar `lib/api.dart` içinde. Önemliler: `factories?quality=ID`, `factories/{id}` (fabrikanın tüm kalite fiyatları), `qualities`, `prices` (doviz/emtia.gruplar/parite), `updates`, `news`, `analyses`, `devices` (girişsiz de kabul eder).
- **Firebase:** proje `mtex-metalexchange`. Ayarlar `lib/firebase_options.dart` içinde koda gömülü (plist/json paketlenmese de çalışır — bilerek böyle, değiştirme).
- **Bildirim:** Herkese yayın = FCM topic **"fiyat"** (girişsiz abone olunur). Sunucudaki push_worker fiyat güncellemelerinde topic'e gönderir (FCM HTTP v1). Bildirim data'sı: `tur=fiyat_guncelleme, fabrika_id, fabrika_slug, fabrika_ad, kalite_id, kalem`; tıklanınca `_bildirimYonlendir` (main.dart) fabrika detayını açar.
- **CI/CD:** Codemagic (`codemagic.yaml`), workflow `ios-testflight` → TestFlight'a otomatik yükler ve "MTEX Test" iç test grubuna otomatik dağıtır. App Store Connect entegrasyon adı: **MTEX_ASC**. Push sonrası derleme OTOMATİK BAŞLAMAZ — Codemagic arayüzünden elle "Start new build" gerekir.
- **Sürümleme:** her TestFlight derlemesinde `pubspec.yaml` version alanındaki build numarasını (+N) artır — artırmazsan Apple reddeder.

## İş kuralları (KESİN)
- Hurda KDV'den MUAF — hiçbir yerde KDV hesabı/kelimesi olmasın.
- İthal parite = (ithal hurda USD + 10 USD) × USD/TRY — backend hesaplar (`parite_tl`), uygulama hesaplamaz.
- Bildirimler otomatik: kullanıcı alarm kurmaz; fabrika fiyat güncelleyince push gider. Bildirim metnine mobilde ekleme yapma (sunucu tek satır gönderir).
- Ana ekran: kalite seçici YOK; 16 fabrikanın tamamı `Api.tumFabrikalar()` ile (tüm kaliteler birleştirilir, fabrika başına EN YÜKSEK fiyat + kalite etiketi). Sıralama backend `oncelik` alanına göre (1=en üst, panelden yönetilir); önceliksizler fiyata göre.
- Eksper Hesabı: fabrika seç → kalite kalite kg gir → satır = kg/1000 × (fiyat + iskonto) → toplam/tonaj = ORTALAMA FİYAT. İskonto ± TL/ton, boşsa etkisiz. Fabrika değişince kg+iskonto sıfırlanır.
- Analiz sekmesi: "Fabrika Haberleri" yalnızca başlığında 'güncelledi' geçen haberler.
- iOS asgari sürüm 15 (Firebase SDK gereksinimi — düşürme).

## Tasarım ("Altın & Çelik")
`lib/theme.dart` MT sınıfı: zemin #0E1220, kart #171D2E, altın #F0B429 (degrade FBD34D→D97706), çelik nötr #94A0B5. `MT.turuncu` adı tarihsel, değeri altın. Fiyatlar `MT.fiyat()` (IBM Plex Mono, tabular); metin Manrope (google_fonts). Başlık: logo + "MTEX HURDA". Açılışta "BİR ERKOÇ HURDA GERİ DÖNÜŞÜM KURULUŞUDUR" markası (assets/branding.png). WhatsApp FAB: wa.me/905308632022.

## Hesaplar / erişim
- GitHub: mkoc6330-oss/mtex-app (bu depo; hâlâ Public — Private önerildi).
- Apple: Team ID 3KP794Y8K2; ASC uygulaması "MTEX Hurda" (id 6797546984, bundle io.metalexchange.mtex); testçiler: dogan.koc@hotmail.com (kurulu), gokhanerkoc1@icloud.com (davet kabulü bekliyor → kabul edince ASC > TestFlight > MTEX Test grubuna ekle).
- Anahtar yedekleri: C:\mtex_keys\ (APNs V84JD7TC7X, ASC API QZGRF693AY; Issuer 7dc7a9cd-bdff-4864-a344-c3dffaa9dfda) — bu bilgisayarda.
- Yerel geliştirme (bu PC): Flutter C:\src\flutter (PATH'te yok), önizleme: `flutter build web --release` + launch.json "mtex-web" (port 5173).

## Bekleyen işler
- [x] App Store yayını: v1.0 (Build 12) 2026-08-06'da incelemeye GÖNDERİLDİ ("Waiting for Review", onayda otomatik yayın; sonuç dogan.koc@hotmail.com'a gelir). Mağaza varlıkları store/eski/ içinde.
- [x] Backend: `doviz.degisim` alanı geldi — rozetler çalışıyor
- [ ] Gökhan Koç ASC davetini kabul edince MTEX Test grubuna ekle
- [ ] TestFlight "Test Information" formu (dış test için; App Store gönderimi yapıldı, engel değil)
- [ ] Google Play: Android keystore + yayın akışı
- [ ] Depoyu Private yap (kullanıcı onaylarsa)
