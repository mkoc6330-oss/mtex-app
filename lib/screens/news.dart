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
  int _sliderSira = 0;
  final _aramaDenetleyici = TextEditingController();
  final _slider = PageController(viewportFraction: .93);

  /// Slider'da gösterilen manşet sayısı; kalanlar öne çıkanlar listesine iner
  static const _manset = 20;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _aramaDenetleyici.dispose();
    _slider.dispose();
    super.dispose();
  }

  /// Süzgeç değişince liste kısalabilir; slider baştan başlamalı
  void _slideriSifirla() {
    _sliderSira = 0;
    if (_slider.hasClients) _slider.jumpToPage(0);
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
                    onChanged: (v) => setState(() {
                      _arama = v;
                      _slideriSifirla();
                    }),
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
                                setState(() {
                                  _arama = '';
                                  _slideriSifirla();
                                });
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
                  if (liste.isNotEmpty) _mansetSlider(liste),
                  if (liste.length > _manset) ...[
                    const SizedBox(height: 20),
                    _oneCikanlar(liste.skip(_manset).toList()),
                  ],
                ],
              ),
            ),
    );
  }

  /// Manşet slider'ı: en yeni 20 haber, elle kaydırılır (ok yok — okumayı
  /// kapatıyordu), altında nokta göstergesi ve sayaç.
  Widget _mansetSlider(List<Map<String, dynamic>> liste) {
    final mansetler = liste.take(_manset).toList();
    final sira = _sliderSira.clamp(0, mansetler.length - 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 292,
        child: PageView.builder(
          controller: _slider,
          itemCount: mansetler.length,
          onPageChanged: (i) => setState(() => _sliderSira = i),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(right: 9),
            child: HaberKarti(haber: mansetler[i], kayan: true),
          ),
        ),
      ),
      const SizedBox(height: 11),
      Row(children: [
        // Çok haberde nokta sığmaz; kayan pencerede en fazla 7 nokta
        ..._noktalar(sira, mansetler.length),
        const Spacer(),
        Text('${sira + 1} / ${mansetler.length}',
            style: MT.fiyat(
                size: 11, weight: FontWeight.w700, color: MT.soluk)),
      ]),
    ]);
  }

  List<Widget> _noktalar(int sira, int toplam) {
    const gorunen = 7;
    var bas = 0;
    if (toplam > gorunen) {
      bas = (sira - gorunen ~/ 2).clamp(0, toplam - gorunen);
    }
    final son = (bas + gorunen).clamp(0, toplam);
    return [
      for (var i = bas; i < son; i++)
        Container(
          width: i == sira ? 17 : 6,
          height: 6,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: i == sira ? MT.altin : MT.cizgi,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ];
  }

  /// Slider'a girmeyen haberler — sitedeki numaralı "Öne Çıkanlar" listesi
  Widget _oneCikanlar(List<Map<String, dynamic>> liste) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.star_rounded, size: 18, color: MT.altin),
          const SizedBox(width: 6),
          const Text('Öne Çıkanlar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('${liste.length} haber',
              style: const TextStyle(fontSize: 11.5, color: MT.soluk)),
        ]),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < liste.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: MT.cizgi),
              _oneCikanSatir(i + 1, liste[i]),
            ],
          ]),
        ),
      ]);

  Widget _oneCikanSatir(int sira, Map<String, dynamic> h) => InkWell(
        onTap: () => habereGit(context, h),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 22,
              child: Text('$sira',
                  style: MT.fiyat(
                      size: 15, weight: FontWeight.w800, color: MT.kirmizi)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((h['baslik'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.33)),
                  const SizedBox(height: 5),
                  Text(
                      '${h['kaynak'] ?? 'MTEX'} · '
                      '${haberZamani(h['tarih'])}',
                      style:
                          const TextStyle(fontSize: 11, color: MT.soluk)),
                ],
              ),
            ),
          ]),
        ),
      );

  Widget _cip(String ad) {
    final secili = _bolum == ad;
    final adet = ad == 'Tümü'
        ? _haberler.length
        : _haberler.where((h) => _haberBolum(h) == ad).length;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() {
        _bolum = ad;
        _slideriSifirla();
      }),
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
