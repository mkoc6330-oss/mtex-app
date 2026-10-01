# MTEX — sunucu tarafı yapılacaklar (mobil uygulama için)

Uygulama tarafı hazır ve yayına çıkabilir durumda. Aşağıdaki iki iş
`metalexchange.io` backend'inde yapılmalı.

---

## 1) İthal hurda fiyatı değiştiğinde bildirim

Uygulama `ithal` adlı FCM konusuna abone. Yurt dışı / ithal hurda fiyatı
(`hurda.ithal_usd`) bir önceki kayda göre değiştiğinde bu konuya **tek**
gönderim yapılması yeterli; tüm cihazlara ulaşır, giriş gerekmez.

**Önemli:** Bildirim metnini tamamen sunucu yazar. Uygulama metne hiçbir
ekleme yapmaz, tek satır olarak gösterir.

```json
{
  "topic": "ithal",
  "notification": {
    "title": "İthal hurda fiyatı değişti",
    "body": "İthal hurda 352 $/ton — 4 $ yükseldi"
  },
  "data": {
    "tur": "ithal_hurda",
    "fiyat_usd": "352",
    "fark_usd": "4"
  },
  "android": { "notification": { "channel_id": "ithal" } }
}
```

- `data.tur` **`ithal_hurda`** olmalı → bildirime dokunan kullanıcı
  uygulamanın **Piyasa** sekmesine düşer.
- Android kanal kimliği: `ithal` (uygulamada tanımlı).
- Düşüşte metin "… — 4 $ düştü" şeklinde kurulur. Fiyatı mutlaka yaz,
  kullanıcı bildirimi açmadan rakamı görsün.
- Aynı fiyat tekrar işlenirse gönderim yapılmasın (fark 0 ise sus).
- KDV hesabı/kelimesi geçmeyecek. Parite hesabı zaten sunucuda.

---

## 2) Uygulama sürüm ucu (Android güncelleme uyarısı için)

Uygulama açılışta mağazadaki sürümü sorup kendinden yeniyse
"uygulamayı güncelleyin" uyarısı gösteriyor. **iOS'ta** bu App Store
sorgusuyla zaten çalışıyor. **Android'de** Play'in herkese açık sürüm
API'si olmadığı için şu uç gerekli:

`GET /api/v1/app/version?platform=android` (ve `?platform=ios`)

```json
{
  "ok": true,
  "surum": "1.0.2",
  "url": "https://play.google.com/store/apps/details?id=io.metalexchange.mtex"
}
```

- `surum` mağazada **yayında olan** sürüm olmalı (pubspec'teki
  `version:` alanının nokta ayrımlı kısmı, ör. `1.0.2`).
- Uç yoksa uygulama sessizce devam eder, hata vermez — yani acele yok,
  eklendiği anda çalışmaya başlar.
- Bu uç varsa iOS için de buradan okunur; iki platform tek yerden yönetilir.

### İsteğe bağlı: sürüm duyurusunu push olarak da gönderme

Uygulama `surum` konusuna da abone. Yeni sürüm yayınlandığında uygulamayı
hiç açmayan kullanıcılara da ulaşmak için:

```json
{
  "topic": "surum",
  "notification": {
    "title": "MTEX 1.0.2 yayında",
    "body": "Yeni özellikler için uygulamayı güncelleyin."
  },
  "data": { "tur": "guncelleme" },
  "android": { "notification": { "channel_id": "guncelleme" } }
}
```

`tur: guncelleme` → dokunulunca mağaza sayfası açılır.

---

## 3) Küçük düzeltme: haber görsellerine CORS başlığı

`/uploads/` altındaki görsellerde `Access-Control-Allow-Origin` yok.
Mobil uygulamayı etkilemiyor, ama web önizlemede ve ileride bir web
sürümünde görseller yüklenemiyor. cPanel'de `/uploads/.htaccess`:

```apache
<IfModule mod_headers.c>
  Header set Access-Control-Allow-Origin "*"
</IfModule>
```

---

## 4) Haber akışına kategori alanı (orta vadeli)

`news_live.php` şu anda 30 haberin tamamını tek kategoriyle (`piyasa`)
gönderiyor. Uygulama bölümleri (Hurda & Metal, Finans, Enerji, Şirketler,
Tarım & Gıda, Gündem) başlık/özet üzerinden kendi çıkarıyor — çalışıyor
ama kaynakta kategori olursa çok daha isabetli olur.

Beslemede `<category>` alanı gerçek kategoriyle doldurulursa veya
`?cat=` parametresi desteklenirse uygulama doğrudan onu kullanır.

Not: `?cat=` ve `?kategori=` parametreleri şu an sessizce yok sayılıyor,
her durumda aynı 30 kayıt dönüyor.

Ayrıca sitenin ana sayfasındaki **"Hurda & LME haberleri"**, **"Emtia
haberleri"** ve **"Finans & kripto haberleri"** blokları hâlâ sayfa
içine gömülü sabit örnek veriyle çalışıyor (26.06 / 29.06 tarihli,
"MTEX AI" ve "BloombergHT" imzalı uydurma kayıtlar). Canlı akışa
bağlanmaları gerekiyor — uygulamada bu bölümler gerçek veriyle çalışıyor.
