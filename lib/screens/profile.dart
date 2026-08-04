import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _uye;
  bool _yukleniyor = true, _kayitModu = false, _islemde = false;
  String? _mesaj;

  final _eposta = TextEditingController();
  final _sifre = TextEditingController();
  final _ad = TextEditingController();
  final _telefon = TextEditingController();
  final _firma = TextEditingController();

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() {
    for (final c in [_eposta, _sifre, _ad, _telefon, _firma]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    if (Api.girisliMi) {
      try {
        final j = await Api.ben();
        if (j['ok'] == true) _uye = j['uye'] as Map<String, dynamic>;
      } catch (_) {}
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _gonder() async {
    setState(() { _islemde = true; _mesaj = null; });
    try {
      final j = _kayitModu
          ? await Api.kayit(
              eposta: _eposta.text.trim(), sifre: _sifre.text,
              ad: _ad.text.trim(), telefon: _telefon.text.trim(), firma: _firma.text.trim())
          : await Api.giris(_eposta.text.trim(), _sifre.text);
      if (j['ok'] == true) {
        _uye = j['uye'] as Map<String, dynamic>;
        _sifre.clear();
      } else {
        _mesaj = (j['mesaj'] ?? 'İşlem tamamlanamadı').toString();
      }
    } catch (e) {
      _mesaj = 'Bağlantı kurulamadı';
    }
    if (mounted) setState(() => _islemde = false);
  }

  Future<void> _cikis() async {
    await Api.cikis();
    if (mounted) setState(() { _uye = null; _mesaj = null; });
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: MT.turuncu))
          : Column(children: [
              _bildirimDurumu(),
              Expanded(child: _uye != null ? _uyeGorunumu() : _girisFormu()),
            ]),
    );
  }

  /// Bildirim altyapısının cihazda gerçekten kurulu olup olmadığını gösterir
  /// (teşhis amaçlı: yeşil = FCM belirteci alınabildi, bildirim gelebilir)
  Widget _bildirimDurumu() {
    final mobil = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!mobil) return const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: _pushBelirteci(),
      builder: (_, s) {
        final bekliyor = s.connectionState != ConnectionState.done;
        final tamam = s.data != null;
        final renk = bekliyor ? MT.soluk : (tamam ? MT.yesil : MT.kirmizi);
        final metin = bekliyor
            ? 'Bildirim durumu denetleniyor…'
            : tamam
                ? 'Bildirimler aktif — fiyat güncellemeleri bu cihaza gelir'
                : 'Bildirim bağlantısı kurulamadı — interneti kontrol edip uygulamayı yeniden açın';
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: renk.withValues(alpha: .35)),
          ),
          child: Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(metin,
                style: TextStyle(fontSize: 12, color: renk,
                    fontWeight: FontWeight.w600))),
          ]),
        );
      },
    );
  }

  Future<String?> _pushBelirteci() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Widget _uyeGorunumu() {
    final bildirim = _uye!['bildirim'] == true;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 16, 14, 30), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A2436), MT.kart],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MT.cizgi),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [MT.turuncu2, MT.turuncu]),
              shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              ((_uye!['ad'] ?? _uye!['email'] ?? 'M').toString().trim().isEmpty
                  ? 'M' : (_uye!['ad'] ?? _uye!['email']).toString().trim())[0].toUpperCase(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(((_uye!['ad'] ?? '').toString().isEmpty
                    ? (_uye!['email'] ?? '').toString() : _uye!['ad'].toString()),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text((_uye!['email'] ?? '').toString(),
                style: const TextStyle(fontSize: 13, color: MT.soluk)),
          ])),
        ]),
      ),
      const SizedBox(height: 16),
      Card(child: Column(children: [
        SwitchListTile(
          value: bildirim,
          activeThumbColor: MT.turuncu,
          onChanged: (v) async {
            setState(() => _uye!['bildirim'] = v);
            try { await Api.bildirimAyar(v); } catch (_) {}
          },
          title: const Text('Fiyat Bildirimleri',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: const Text('Fabrikalar fiyat güncellediğinde haber ver',
              style: TextStyle(fontSize: 12.5, color: MT.soluk)),
        ),
      ])),
      const SizedBox(height: 16),
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Hesap Bilgileri',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _bilgi('Telefon', (_uye!['telefon'] ?? '—').toString()),
          _bilgi('Firma', (_uye!['firma'] ?? '—').toString()),
          _bilgi('Doğrulama', _uye!['dogrulandi'] == true ? 'Doğrulandı' : 'Bekliyor'),
        ]),
      )),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: _cikis,
        icon: const Icon(Icons.logout, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: MT.kirmizi,
          side: const BorderSide(color: Color(0xFF3A2A2E)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        label: const Text('Çıkış Yap'),
      ),
      const SizedBox(height: 20),
      const Center(child: Text('MTEX · metalexchange.io',
          style: TextStyle(fontSize: 11.5, color: MT.soluk))),
    ]);
  }

  Widget _bilgi(String s, String d) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(s, style: const TextStyle(fontSize: 13.5, color: MT.soluk)),
          Text(d, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _girisFormu() => ListView(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 30),
        children: [
          const Icon(Icons.factory, size: 46, color: MT.turuncu),
          const SizedBox(height: 14),
          Text(_kayitModu ? 'MTEX Üyeliği' : 'Giriş Yap',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Fiyat güncelleme bildirimleri ve kişisel takip için üye ol',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: MT.soluk, height: 1.5)),
          const SizedBox(height: 24),
          if (_kayitModu) ...[
            TextField(controller: _ad,
                decoration: const InputDecoration(labelText: 'Ad Soyad')),
            const SizedBox(height: 11),
            TextField(controller: _telefon, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon')),
            const SizedBox(height: 11),
            TextField(controller: _firma,
                decoration: const InputDecoration(labelText: 'Firma (opsiyonel)')),
            const SizedBox(height: 11),
          ],
          TextField(controller: _eposta, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta')),
          const SizedBox(height: 11),
          TextField(controller: _sifre, obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre')),
          if (_mesaj != null) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: MT.kirmizi.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: MT.kirmizi.withValues(alpha: .3))),
              child: Text(_mesaj!, style: const TextStyle(fontSize: 13, color: MT.kirmizi)),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _islemde ? null : _gonder,
            style: FilledButton.styleFrom(
              backgroundColor: MT.turuncu,
              padding: const EdgeInsets.symmetric(vertical: 15)),
            child: _islemde
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_kayitModu ? 'Üye Ol' : 'Giriş Yap',
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => setState(() { _kayitModu = !_kayitModu; _mesaj = null; }),
            child: Text(
              _kayitModu ? 'Zaten üyeyim — giriş yap' : 'Üye değil misin? Kayıt ol',
              style: const TextStyle(color: MT.turuncu, fontSize: 13.5)),
          ),
        ],
      );
}
