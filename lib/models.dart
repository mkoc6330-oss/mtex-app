/// Basit veri modelleri
class Fabrika {
  final int id, sira;
  final String ad, tamAd;
  final String? bolge, logo, tarih;
  final double fiyat;
  final num? ortalamaFark;

  Fabrika.json(Map<String, dynamic> j)
      : id = (j['id'] ?? 0) as int,
        sira = (j['sira'] ?? 0) as int,
        ad = (j['ad'] ?? '') as String,
        tamAd = (j['tam_ad'] ?? '') as String,
        bolge = j['bolge'] as String?,
        logo = j['logo'] as String?,
        tarih = j['tarih'] as String?,
        fiyat = ((j['fiyat'] ?? 0) as num).toDouble(),
        ortalamaFark = j['ortalama_fark'] as num?;
}

class Kalite {
  final int id;
  final String ad, slug;
  Kalite.json(Map<String, dynamic> j)
      : id = (j['id'] ?? 0) as int,
        ad = (j['ad'] ?? '') as String,
        slug = (j['slug'] ?? '') as String;
}

class Makale {
  final int id;
  final String baslik;
  final String? ozet, gorsel, tarih, kaynak, icerikHtml;

  Makale.json(Map<String, dynamic> j)
      : id = (j['id'] ?? 0) as int,
        baslik = (j['baslik'] ?? '') as String,
        ozet = j['ozet'] as String?,
        gorsel = j['gorsel'] as String?,
        tarih = j['tarih'] as String?,
        kaynak = j['kaynak'] as String?,
        icerikHtml = j['icerik_html'] as String?;
}

class Guncelleme {
  final int id, fabrikaId;
  final String? fabrika, kalite, mesaj, zaman;
  final num? eski, yeni, fark;

  Guncelleme.json(Map<String, dynamic> j)
      : id = (j['id'] ?? 0) as int,
        fabrikaId = (j['fabrika_id'] ?? 0) as int,
        fabrika = j['fabrika'] as String?,
        kalite = j['kalite'] as String?,
        mesaj = j['mesaj'] as String?,
        zaman = j['zaman'] as String?,
        eski = j['eski'] as num?,
        yeni = j['yeni'] as num?,
        fark = j['fark'] as num?;
}
