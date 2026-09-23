# BizimŞarj — Risk Listesi

Olasılık (O) ve etki (E): Y = yüksek, O = orta, D = düşük.

| # | Risk | O | E | Azaltma | Sahip |
|---|---|---|---|---|---|
| 1 | **EPDK lisansı:** Türkiye'de son kullanıcıya şarj hizmeti satmak "şarj hizmeti lisansı" gerektirir (Şarj Hizmetleri Yönetmeliği). Lisanssız doğrudan satış yapılamaz. | Y | Y | İki model: (a) BizimŞarj lisans alır (asgari şartlar hukukçuyla netleştirilmeli), (b) lisanslı operatör adına aracı platform olur, fatura operatör adına kesilir. **Canlı ödeme almadan önce hukuki görüş şart.** | Kurucu + hukuk |
| 2 | **Ödeme modeli / lisans:** Operatör adına para toplayıp dağıtmak ödeme kuruluşu lisansı (6493) konusu olabilir. | O | Y | Pazaryeri (alt üye işyeri) ödeme ürünü: para doğrudan operatöre bölünür, biz komisyon alırız. Nakit cüzdan bakiyesi YOK (yalnızca promosyon kredisi). | Kurucu + hukuk |
| 3 | **KVKK yurt dışı aktarım:** Yurt dışı VPS'te kişisel veri. | O | O | Standart sözleşme + bildirim veya TR'de VPS (maliyet farkı ~500–800 TL/ay). Karar Faz 20 öncesi. | Kurucu |
| 4 | **Cihaz OCPP uyumsuzluğu:** Üreticiler spesifikasyonu farklı yorumlar (1.6'da özellikle MeterValues, StatusNotification sırası). | Y | O | Sürücü içinde üretici bazlı "quirk" katmanı; her yeni model için simülatör + gerçek test listesi; esnek şema modu (bilinmeyen alanları yok say, loglama). | Backend |
| 5 | **Cihaz bağlantısı:** GSM modem kopmaları, NAT, TLS/sertifika zinciri desteği olmayan eski firmware. | Y | O | Stale tespiti, retry/backoff önerileri, Let's Encrypt zincir uyumluluğu kontrolü, gerekirse özel APN/VPN. | Operasyon |
| 6 | **Tek VPS = tek arıza noktası (Aşama 1).** | O | Y | Günlük şifreli yedek + haftalık geri yükleme testi; kurtarma betiği ile < 2 saatte yeni sunucu; cihazlar bağlantı koptuğunda işlemi yerelde sürdürür ve sonra gönderir. Aşama 2'de ayrıştırma. | DevOps |
| 7 | **Güven skoru manipülasyonu** (rakip/kötü niyetli check-in). | O | O | GPS yakınlık, bekleme süresi, günlük limit, hesap yaşı, itibar, seansla doğrulama; tek kullanıcının etkisi en fazla −15. | Ürün |
| 8 | **Yanlış "yeşil"** — güveni zedeleyen tek hata türü. | O | Y | Şüphede 🟡/⚫ göster; ölçüt: 🟢'de başarısız başlatma < %3, haftalık izlenir. | Ürün |
| 9 | **Çift tahsilat / tahsil edilemeyen şarj.** | D | Y | Idempotency, provizyon-önce-başlat, mutabakat, defter, DB kısıtları, senaryo testleri. | Backend |
| 10 | **Tarife/fiyat hatası** (operatör yanlış girer). | O | O | Yeni tarife sürümü + önizleme + makul aralık uyarısı (ör. > 30 TL/kWh). | Operatör paneli |
| 11 | **Veri kapsamı:** 10 cihazla kullanıcı çekmek zor; diğer ağların verisi yok. | Y | O | OCPI/partner anlaşmaları, kullanıcı önerisi + check-in (crowd kaynaklı istasyonlar `source=crowd`, düşük veri kalitesi skoru ile). Kazıma (scraping) yapılmaz — hukuki risk. | İş geliştirme |
| 12 | **App Store / Play ret:** ödeme akışı, konum izni gerekçesi. | O | D | Fiziksel hizmet → uygulama içi satın alma (IAP) gerekmez; izin metinleri net. | Mobil |
| 13 | **Kur riski:** Sunucular EUR/USD. | O | D | Maliyet küçük; TR VPS seçeneği. | Kurucu |
| 14 | **Kilit kişi:** tek geliştirici. | Y | O | Dokümantasyon (bu klasör), testler, tek komutla kurulum. | Kurucu |
| 15 | **90 gün takvimi iddialı.** | O | O | Kapsam korunur: rota planlama ve sıra tahmini gerekirse MVP sonrasına kayar; ödeme + başlatma + güven skoru asla kaymaz. | Proje |
| 16 | **Otomatik reset ile güvenlik olayı.** | D | Y | Ağ bazlı politika, aktif seans varken asla, saatte 1 sınırı, GroundFailure vb. elektriksel hatalarda hiçbir uzaktan aksiyon, AI komut gönderemez. | Backend |
| 17 | **Depo erişimi:** Bu doküman şu an `mtex-app` deposunda (hâlâ Public). | Y | O | Ayrı **Private** `bizimsarj` deposuna taşı; sırlar zaten depoda değil. | Kurucu |
