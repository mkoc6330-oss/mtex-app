# MTEX — Mobil Uygulama

Hurda, çelik ve emtia piyasası. Veriler `metalexchange.io/api/v1` üzerinden gelir.

## Ekranlar
- **Fabrikalar** — sıralı liste, dokununca fiyat detayı + 45 günlük grafik
- **Piyasa** — inşaat demiri, kütük, hurda, döviz, parite, emtia
- **Hesapla** — tonaj gir, fabrikaları karşılaştır *(hurda KDV'den muaf, KDV kullanılmaz)*
- **Analiz** — MTEX piyasa analizleri + haberler
- **Profil** — üyelik, bildirim ayarı

## Bildirimler
Fabrika fiyat güncellediğinde otomatik push gelir:
> **İSDEMİR fiyat güncelledi** — Bonus: 17.250 TL

Sunucu tarafı `api/v1/push_worker.php` 15 dakikada bir kontrol eder.

## Kurulum

1. Flutter SDK 3.x kur
2. Firebase yapılandırma dosyalarını yerleştir:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   
   (Firebase Console → mtex-metalexchange → Proje Ayarları → Uygulamalarım → indir)
3. `flutter pub get`
4. İkon: `assets/icon.png` (1024×1024) koy → `flutter pub run flutter_launcher_icons`

## Derleme
```bash
flutter build appbundle --release    # Google Play
flutter build ipa --release          # App Store (Mac gerekir veya Codemagic)
```

## Kimlik
- Paket / Bundle ID: `io.metalexchange.mtex`
- Firebase projesi: `mtex-metalexchange`
