import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/haber_karti.dart';

/// Sitedeki "Ekonomi Haberleri" sayfasının uygulama karşılığı:
/// kaynak süzgeci, arama ve site düzeniyle aynı haber kartları.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, dynamic>> _haberler = [];
  bool _yukleniyor = true;
  String _arama = '';
  String _kaynak = 'Tümü';
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

  List<String> get _kaynaklar {
    final s = <String>{};
    for (final h in _haberler) {
      s.add((h['kaynak'] ?? 'MTEX').toString());
    }
    return ['Tümü', ...s];
  }

  List<Map<String, dynamic>> get _suzgecli {
    final a = _arama.toLowerCase().trim();
    return _haberler.where((h) {
      if (_kaynak != 'Tümü' &&
          (h['kaynak'] ?? 'MTEX').toString() != _kaynak) {
        return false;
      }
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
      appBar: AppBar(title: const Text('Ekonomi Haberleri')),
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
                      'Anadolu Ajansı ekonomi haberleri — hurda ve metal '
                      'fiyatları için Fabrikalar sekmesi',
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
                      for (final k in _kaynaklar) ...[
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
    final secili = _kaynak == ad;
    final adet = ad == 'Tümü'
        ? _haberler.length
        : _haberler.where((h) => (h['kaynak'] ?? 'MTEX') == ad).length;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _kaynak = ad),
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
