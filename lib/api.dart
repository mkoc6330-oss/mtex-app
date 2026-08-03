import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static Future<Map<String, dynamic>> haber(int id) => _al('news/$id');
  static Future<Map<String, dynamic>> analizler({int limit = 15}) =>
      _al('analyses?limit=$limit');
  static Future<Map<String, dynamic>> guncellemeler({int limit = 25}) =>
      _al('updates?limit=$limit');

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

  // ---------- Push cihaz kaydı ----------
  static Future<void> cihazKaydet(String pushToken, String platform) async {
    if (!girisliMi) return;
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
}
