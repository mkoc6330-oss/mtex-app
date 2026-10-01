import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

/// MTEX API servis katmanı — metalexchange.io/api/v1
class Api {
  static const kok = 'https://metalexchange.io/api/v1';
  static String? _token;

  static Future<void> baslat() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('token');
  }

  static String? get token => _token;
  static bool get girisliMi => _token != null && _token!.isNotEmpty;

  static Future<void> _tokenKaydet(String? t) async {
    _token = t;
    final sp = await SharedPreferences.getInstance();
    if (t == null) {
      await sp.remove('token');
    } else {
      await sp.setString('token', t);
    }
  }

  static Map<String, String> _basliklar({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>> _al(String yol) async {
    final r = await http
        .get(Uri.parse('$kok/$yol'), headers: _basliklar())
        .timeout(const Duration(seconds: 20));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is Map<String, dynamic>) return j;
    return {'ok': false};
  }

  static Future<Map<String, dynamic>> _gonder(
      String yol, Map<String, dynamic> govde,
      {String metot = 'POST'}) async {
    final u = Uri.parse('$kok/$yol');
    final b = jsonEncode(govde);
    final h = _basliklar(json: true);
    late http.Response r;
    if (metot == 'PUT') {
      r = await http.put(u, headers: h, body: b);
    } else if (metot == 'DELETE') {
      r = await http.delete(u, headers: h, body: b);
    } else {
      r = await http.post(u, headers: h, body: b);
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is Map<String, dynamic>) return j;
    return {'ok': false};
  }

  // ---------- Genel veriler ----------
  static Future<Map<String, dynamic>> fiyatlar() => _al('prices');
  static Future<Map<String, dynamic>> fabrikalar({int? kaliteId}) =>
      _al('factories${kaliteId != null ? '?quality=$kaliteId' : ''}');
  static Future<Map<String, dynamic>> kaliteler() => _al('qualities');
  static Future<Map<String, dynamic>> gecmis(int fabrikaId,
          {int gun = 45, int? kaliteId}) =>
      _al('factories/$fabrikaId/history?days=$gun'
          '${kaliteId != null ? '&quality=$kaliteId' : ''}');
  static Future<Map<String, dynamic>> haberler({int limit = 20}) =>
      _al('news?limit=$limit');

  // ---------- Canlı haber akışı (web sitesinin ana sayfa beslemesi) ----------
  static const _haberAkisi = 'https://metalexchange.io/prototip/news_live.php';
  static List<Map<String, dynamic>>? _akisCache;
  static DateTime? _akisZamani;

  /// Sitedeki "Son haberler" bölümüyle aynı RSS beslemesi.
  /// Dönen kayıtlar: {baslik, ozet, gorsel, link, kategori, tarih}
  /// 10 dakika önbellekte tutulur.
  static Future<List<Map<String, dynamic>>> canliHaberler(
      {bool yenile = false}) async {
    if (!yenile &&
        _akisCache != null &&
        DateTime.now().difference(_akisZamani!).inMinutes < 10) {
      return _akisCache!;
    }
    try {
      final r = await http
          .get(Uri.parse(_haberAkisi))
          .timeout(const Duration(seconds: 20));
      final belge = XmlDocument.parse(utf8.decode(r.bodyBytes));
      final liste = <Map<String, dynamic>>[];
      for (final o in belge.findAllElements('item')) {
        String metin(String ad) {
          final e = o.findElements(ad);
          return e.isEmpty ? '' : e.first.innerText.trim();
        }

        final gorselEl = o.findElements('enclosure');
        final link = metin('link');
        final gorsel =
            gorselEl.isEmpty ? null : gorselEl.first.getAttribute('url');
        liste.add({
          'baslik': metin('title'),
          'ozet': metin('description'),
          'link': link,
          'kategori': metin('category'),
          'tarih': _rssTarih(metin('pubDate')),
          'gorsel': gorsel,
          'kaynak': _akisKaynak(gorsel),
          'bolum': _haberBolumu(metin('title'), metin('description')),
          // Haber MTEX'e aitse (kendi sitemizdeki haber sayfası) uygulama
          // içinde tam metin açılabilsin diye id çıkarılır.
          'id': _mtexHaberId(link),
        });
      }
      if (liste.isNotEmpty) {
        _akisCache = liste;
        _akisZamani = DateTime.now();
      }
      return liste;
    } catch (_) {
      return _akisCache ?? [];
    }
  }

  /// Sitedeki haber bölümleri (hurda & metal, finans, enerji…). Akış tek
  /// kategoriyle ("piyasa") geldiği için ayrım başlık ve özetten çıkarılır.
  /// Sıra önemlidir: ilk eşleşen bölüm kazanır, en alakalı en üstte.
  static final _bolumKurallari = <(String, RegExp)>[
    ('Hurda & Metal', RegExp(
        r'hurda|çelik|metal|maden|alüminyum|bakır|demir|alaşım|döküm|'
        r'ferro|nikel|çinko|kurşun|paslanmaz|haddehane|ingot|'
        r'kütük|filmaşin|\blme\b|\bslab\b',
        caseSensitive: false)),
    ('Enerji', RegExp(
        r'petrol|doğal ?gaz|enerji|elektrik|akaryakıt|benzin|motorin|epdk|'
        r'yenilenebilir|güneş enerjisi|rüzgar|kömür|brent|varil|\blng\b',
        caseSensitive: false)),
    // Kısa kalıplar sınırlandırıldı: sınırsız "ons" sponsor/konsorsiyum,
    // "fon" ise fonksiyon gibi kelimelerin içinde eşleşiyordu.
    ('Finans', RegExp(
        r'borsa|faiz|merkez bankası|dolar|euro|döviz|kripto|bitcoin|'
        r'banka|tahvil|hisse|enflasyon|kredi|bütçe|vergi|altın|gümüş|'
        r'yatırım fonu|fonlar|kurlar|\bbist\b|\bspk\b|\bons\b|'
        r'\btüfe\b|\büfe\b',
        caseSensitive: false)),
    ('Tarım & Gıda', RegExp(
        r'tarım|buğday|pamuk|hububat|çiftçi|hasat|gıda|tohum|hayvancılık|'
        r'süt|arıcılık|zeytin|fındık|meyve|sebze|orman|\bbal\b',
        caseSensitive: false)),
    ('Şirketler', RegExp(
        r'a\.ş|anonim şirket|holding|ihracat sözleşmesi|şirketi|'
        r'yatırım yapacak|imzaladı|satın aldı|halka arz',
        caseSensitive: false)),
  ];

  @visibleForTesting
  static String haberBolumu(String baslik, String ozet) =>
      _haberBolumu(baslik, ozet);

  static String _haberBolumu(String baslik, String ozet) {
    final metin = '$baslik $ozet';
    for (final (ad, kural) in _bolumKurallari) {
      if (kural.hasMatch(metin)) return ad;
    }
    return 'Gündem';
  }

  /// RSS'te kaynak alanı yok; görsel yolundan çıkarılır. Lisanslı ajans
  /// içeriğinde künye zorunlu olduğu için kart ve okuma ekranında gösterilir.
  static String _akisKaynak(String? gorsel) {
    final g = gorsel ?? '';
    if (g.contains('/haber/aa/')) return 'Anadolu Ajansı';
    return 'MTEX';
  }

  /// Bağlantı MTEX'in kendi haber sayfasıysa haber id'sini döndürür
  /// (…/haber.php?id=51378). Değilse null → kaynak sitede açılır.
  static int? _mtexHaberId(String link) {
    if (!link.contains('metalexchange.io')) return null;
    final m = RegExp(r'[?&]id=(\d+)').firstMatch(link);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// "Tue, 18 Aug 2026 06:49:00 +0000" → DateTime (yerel saat)
  static DateTime? _rssTarih(String s) {
    if (s.isEmpty) return null;
    const aylar = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final m = RegExp(r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2})')
        .firstMatch(s);
    if (m == null) return null;
    final ay = aylar[m.group(2)];
    if (ay == null) return null;
    return DateTime.utc(int.parse(m.group(3)!), ay, int.parse(m.group(1)!),
            int.parse(m.group(4)!), int.parse(m.group(5)!))
        .toLocal();
  }
  static Future<Map<String, dynamic>> haber(int id) => _al('news/$id');
  static Future<Map<String, dynamic>> analizler({int limit = 15}) =>
      _al('analyses?limit=$limit');
  static Future<Map<String, dynamic>> guncellemeler({int limit = 25}) =>
      _al('updates?limit=$limit');

  static List<Map<String, dynamic>>? _tumFabCache;
  static DateTime? _tumFabZamani;

  /// Tüm fabrikalar (kalite ayrımı olmadan). Her fabrika için EN YÜKSEK alım
  /// fiyatı ve o fiyatın kalite adı döner; fiyata göre azalan sıralıdır.
  /// API'de tüm-fabrika ucu olmadığından kaliteler paralel çekilip
  /// birleştirilir; sonuç 5 dakika önbellekte tutulur.
  static Future<List<Map<String, dynamic>>> tumFabrikalar(
      {bool yenile = false}) async {
    if (!yenile &&
        _tumFabCache != null &&
        DateTime.now().difference(_tumFabZamani!).inMinutes < 5) {
      return _tumFabCache!;
    }
    final kj = await kaliteler();
    if (kj['ok'] != true) return _tumFabCache ?? [];
    final kaliteListesi = (kj['kaliteler'] as List).cast<Map<String, dynamic>>();

    final yanitlar = await Future.wait(kaliteListesi.map((k) async {
      try {
        final y = await fabrikalar(kaliteId: k['id'] as int);
        return y['ok'] == true ? {'kalite': k['ad'], 'yanit': y} : null;
      } catch (_) {
        return null;
      }
    }));

    final birlesik = <int, Map<String, dynamic>>{};
    // YYYY-AA-GG dizgileri sözlük sırasıyla karşılaştırılabilir
    String? enYeni(String? a, String? b) {
      if (a == null || a.isEmpty) return b;
      if (b == null || b.isEmpty) return a;
      return a.compareTo(b) >= 0 ? a : b;
    }

    for (final s in yanitlar.whereType<Map<String, dynamic>>()) {
      final y = s['yanit'] as Map<String, dynamic>;
      for (final f in (y['fabrikalar'] as List).cast<Map<String, dynamic>>()) {
        final id = f['id'] as int;
        final fiyat = (f['fiyat'] ?? 0) as num;
        final mevcut = birlesik[id];
        // son_tarih: fabrikanın HERHANGİ bir kalitesindeki en yeni
        // güncelleme günü ("bugün güncelledi" vurgusu bunu kullanır)
        final sonTarih = enYeni(
            mevcut?['son_tarih'] as String?, f['tarih'] as String?);
        if (mevcut == null || fiyat > (mevcut['fiyat'] as num)) {
          birlesik[id] = {...f, 'kalite': s['kalite'], 'son_tarih': sonTarih};
        } else if (sonTarih != mevcut['son_tarih']) {
          birlesik[id] = {...mevcut, 'son_tarih': sonTarih};
        }
      }
    }

    // Sıralama: backend `oncelik` verdiyse (1 = en üst) önce o,
    // öncelik verilmeyenler fiyata göre azalan sırada devam eder.
    final sirali = birlesik.values.toList()
      ..sort((a, b) {
        final oa = a['oncelik'] as num?;
        final ob = b['oncelik'] as num?;
        if (oa != null || ob != null) {
          if (oa == null) return 1;
          if (ob == null) return -1;
          final c = oa.compareTo(ob);
          if (c != 0) return c;
        }
        return (b['fiyat'] as num).compareTo(a['fiyat'] as num);
      });
    if (sirali.isNotEmpty) {
      _tumFabCache = sirali;
      _tumFabZamani = DateTime.now();
    }
    return sirali;
  }

  /// Bir fabrikanın her kalitesi için SON fiyat değişimi (güncel − önceki).
  /// Değişim geçmiş serisinden bulunur: sondan geriye gidilip fiyatın en son
  /// hangi değerden değiştiği aranır. Hiç değişim yoksa kalite listeye girmez.
  /// İstekler paralel gider, biri düşerse diğerleri etkilenmez.
  static Future<Map<int, num>> kaliteDegisimleri(
      int fabrikaId, List<int> kaliteIdler) async {
    final sonuc = <int, num>{};
    await Future.wait(kaliteIdler.map((kid) async {
      try {
        final j = await gecmis(fabrikaId, gun: 120, kaliteId: kid);
        if (j['ok'] != true) return;
        final seri = (j['seri'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        if (seri.length < 2) return;
        final son = (seri.last['fiyat'] as num).toDouble();
        for (var i = seri.length - 2; i >= 0; i--) {
          final onceki = (seri[i]['fiyat'] as num).toDouble();
          if (onceki != son) {
            sonuc[kid] = son - onceki;
            break;
          }
        }
      } catch (_) {}
    }));
    return sonuc;
  }

  /// Bir fabrikanın satın aldığı tüm kalitelerin güncel fiyatları.
  /// `factories/{id}` ucundan tek istekle gelir; fiyata göre azalan sıralıdır:
  /// [{'kalite_id': 1, 'kalite': 'DKP', 'fiyat': 17450, 'tarih': '2026-07-30'}, ...]
  static Future<List<Map<String, dynamic>>> fabrikaKaliteFiyatlari(
      int fabrikaId) async {
    final j = await _al('factories/$fabrikaId');
    if (j['ok'] != true) return [];
    return (j['kaliteler'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((k) => k['fiyat'] != null)
        .toList();
  }

  // ---------- Kimlik ----------
  static Future<Map<String, dynamic>> giris(String eposta, String sifre,
      {String? pushToken}) async {
    final j = await _gonder('auth/login', {
      'email': eposta,
      'password': sifre,
      'platform': 'mobil',
      if (pushToken != null) 'push_token': pushToken,
    });
    if (j['ok'] == true && j['token'] != null) await _tokenKaydet(j['token']);
    return j;
  }

  static Future<Map<String, dynamic>> kayit({
    required String eposta,
    required String sifre,
    String? ad,
    String? telefon,
    String? firma,
    String? pushToken,
  }) async {
    final j = await _gonder('auth/register', {
      'email': eposta,
      'password': sifre,
      'full_name': ad ?? '',
      'phone': telefon ?? '',
      'company': firma ?? '',
      'platform': 'mobil',
      if (pushToken != null) 'push_token': pushToken,
    });
    if (j['ok'] == true && j['token'] != null) await _tokenKaydet(j['token']);
    return j;
  }

  static Future<void> cikis() async {
    try {
      await _gonder('auth/logout', {});
    } catch (_) {}
    await _tokenKaydet(null);
  }

  static Future<Map<String, dynamic>> ben() => _al('me');

  /// Hesabı ve bağlı kişisel verileri KALICI olarak siler (geri alınamaz).
  /// Başarıda oturum da kapatılır.
  static Future<Map<String, dynamic>> hesapSil() async {
    final j = await _gonder('auth/account', {}, metot: 'DELETE');
    if (j['ok'] == true) await _tokenKaydet(null);
    return j;
  }

  // ---------- Push cihaz kaydı ----------
  // Giriş şartı yok: bildirimler üye olmayan kullanıcılara da gider.
  static Future<void> cihazKaydet(String pushToken, String platform) async {
    try {
      await _gonder('devices', {
        'push_token': pushToken,
        'platform': platform,
        'device_name': 'MTEX',
      });
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> bildirimAyar(bool acik) =>
      _gonder('notify', {'acik': acik}, metot: 'PUT');

  // ---------- Mağaza sürümü ----------
  static const appStoreUrl =
      'https://apps.apple.com/tr/app/mtex-hurda/id6797546984';
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=io.metalexchange.mtex';

  /// Mağazadaki yayında olan sürüm: {'surum': '1.0.2', 'url': '…'}.
  /// Önce sunucudaki sürüm ucu denenir (iki platform tek yerden yönetilsin),
  /// yoksa iOS'ta App Store'un kendi sorgusuna düşülür. Play'in herkese açık
  /// sürüm API'si olmadığından Android'de sunucu ucu şart.
  /// Bulunamazsa null döner — uygulama sessizce devam eder.
  static Future<Map<String, String>?> magazaSurumu(String platform) async {
    try {
      final j = await _al('app/version?platform=$platform');
      final s = (j['surum'] ?? j['version'] ?? '').toString();
      if (j['ok'] == true && s.isNotEmpty) {
        final u = (j['url'] ?? '').toString();
        return {'surum': s, 'url': u.isEmpty ? _magazaUrl(platform) : u};
      }
    } catch (_) {}

    if (platform != 'ios') return null;
    try {
      final r = await http
          .get(Uri.parse('https://itunes.apple.com/lookup'
              '?bundleId=io.metalexchange.mtex&country=tr'))
          .timeout(const Duration(seconds: 15));
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final sonuc = (j['results'] as List?) ?? const [];
      if (sonuc.isEmpty) return null;
      final ilk = (sonuc.first as Map).cast<String, dynamic>();
      final s = (ilk['version'] ?? '').toString();
      if (s.isEmpty) return null;
      return {
        'surum': s,
        'url': (ilk['trackViewUrl'] ?? appStoreUrl).toString(),
      };
    } catch (_) {}
    return null;
  }

  static String _magazaUrl(String platform) =>
      platform == 'ios' ? appStoreUrl : playStoreUrl;
}
