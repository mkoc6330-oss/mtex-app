import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/haber_karti.dart';

/// Sitedeki haber bölümünün uygulama karşılığı: bölüm süzgeci (hurda &
/// metal, finans, enerji…), arama ve site düzeniyle aynı haber kartları.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, dynamic>> _haberler = [];
  bool _yukleniyor = true;
  String _arama = '';
  String _bolum = 'Tümü';
  final _aramaDenetleyici = TextEditingController();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _aramaDenetleyici.dispose();
    super.dispose();
  }

  Future<void> _yukle({bool yenile = false}) async {
    if (!yenile) setState(() => _yukleniyor = true);
    try {
      final h = await Api.canliHaberler(yenile: yenile);
      if (mounted) setState(() => _haberler = h);
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  /// Yalnızca haberi olan bölümler gösterilir; sıra api.dart'taki
  /// bölüm sırasıyla aynıdır (en alakalı başta, Gündem sonda).
  List<String> get _bolumler {
    const sira = [
      'Hurda & Metal', 'Finans', 'Enerji', 'Şirketler', 'Tarım & Gıda',
      'Gündem',
    ];
    final mevcut = _haberler.map((h) => _haberBolum(h)).toSet();
    return ['Tümü', ...sira.where(mevcut.contains)];
  }

  static String _haberBolum(Map<String, dynamic> h) =>
      (h['bolum'] ?? 'Gündem').toString();

  List<Map<String, dynamic>> get _suzgecli {
    final a = _arama.toLowerCase().trim();
    return _haberler.where((h) {
      if (_bolum != 'Tümü' && _haberBolum(h) != _bolum) return false;
      if (a.isEmpty) return true;
      final metin =
          '${h['baslik'] ?? ''} ${h['ozet'] ?? ''}'.toLowerCase();
      return metin.contains(a);
    }).toList();
  }

  @override
  Widget build(BuildContext c) {
    final liste = _suzgecli;
    return Scaffold(
      appBar: AppBar(title: const Text('Haberler')),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: MT.altin))
          : RefreshIndicator(
              color: MT.altin,
              backgroundColor: MT.kart,
              onRefresh: () => _yukle(yenile: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 26),
                children: [
                  const Text(
                      'Hurda & metal, finans, enerji ve piyasa haberleri '
                      '— Anadolu Ajansı',
                      style: TextStyle(
                          fontSize: 12.5, color: MT.soluk, height: 1.45)),
                  const SizedBox(height: 13),
                  TextField(
                    controller: _aramaDenetleyici,
                    onChanged: (v) => setState(() => _arama = v),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Haberlerde ara...',
                      hintStyle:
                          const TextStyle(color: MT.soluk, fontSize: 14),
                      prefixIcon:
                          const Icon(Icons.search, color: MT.soluk, size: 19),
                      suffixIcon: _arama.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close,
                                  color: MT.soluk, size: 19),
                              onPressed: () {
                                _aramaDenetleyici.clear();
                                setState(() => _arama = '');
                              }),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final k in _bolumler) ...[
                        _cip(k),
                        const SizedBox(width: 8),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 14),
                  if (liste.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(
                          child: Text('Aramayla eşleşen haber yok',
                              style: TextStyle(color: MT.soluk))),
                    ),
                  for (final h in liste) ...[
                    HaberKarti(haber: h),
                    const SizedBox(height: 11),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _cip(String ad) {
    final secili = _bolum == ad;
    final adet = ad == 'Tümü'
        ? _haberler.length
        : _haberler.where((h) => _haberBolum(h) == ad).length;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _bolum = ad),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: secili ? MT.altin : MT.kart,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: secili ? MT.altin : MT.cizgi),
        ),
        child: Text('$ad ($adet)',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: secili ? MT.altinUstu : MT.yazi)),
      ),
    );
  }
}
