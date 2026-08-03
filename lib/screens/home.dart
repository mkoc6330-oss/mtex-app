import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'factory_detail.dart';

final tlBicim = NumberFormat.decimalPattern('tr_TR');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Fabrika> _fab = [];
  num? _ortalama, _makas;
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() { _yukleniyor = true; _hata = null; });
    try {
      final f = await Api.fabrikalar();
      if (f['ok'] == true) {
        _fab = (f['fabrikalar'] as List).map((e) => Fabrika.json(e)).toList();
        _ortalama = f['ortalama'] as num?;
        _makas = f['makas'] as num?;
      } else {
        _hata = 'Veri alınamadı';
      }
    } catch (e) {
      _hata = 'Bağlantı kurulamadı';
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset('assets/logo.png', width: 26, height: 26),
          ),
          const SizedBox(width: 9),
          const Text.rich(TextSpan(children: [
            TextSpan(text: 'MTEX ',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)),
            TextSpan(text: 'HURDA',
                style: TextStyle(fontWeight: FontWeight.w800,
                    letterSpacing: .5, color: MT.altin)),
          ])),
        ]),
        actions: [
          IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh, color: MT.soluk)),
        ],
      ),
      body: RefreshIndicator(
        color: MT.turuncu,
        backgroundColor: MT.kart,
        onRefresh: _yukle,
        child: _yukleniyor && _fab.isEmpty
            ? const Center(child: CircularProgressIndicator(color: MT.turuncu))
            : _hata != null && _fab.isEmpty
                ? _hataGorunumu()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                    children: [
                      _ozetSatiri(),
                      const SizedBox(height: 14),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Fabrika Sıralaması',
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                      ),
                      ..._fab.map(_fabrikaKarti),
                      if (_fab.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(child: Text('Bu kalite için fiyat verisi yok',
                              style: TextStyle(color: MT.soluk))),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _hataGorunumu() => ListView(children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off, size: 44, color: MT.soluk),
        const SizedBox(height: 12),
        Center(child: Text(_hata ?? '', style: const TextStyle(color: MT.soluk))),
        const SizedBox(height: 14),
        Center(child: FilledButton(
          onPressed: _yukle,
          style: FilledButton.styleFrom(backgroundColor: MT.turuncu),
          child: const Text('Tekrar dene'),
        )),
      ]);

  Widget _ozetSatiri() => Row(children: [
        Expanded(child: _miniKart('Ortalama',
            _ortalama != null ? tlBicim.format(_ortalama) : '—', 'TL/ton', MT.yazi)),
        const SizedBox(width: 10),
        Expanded(child: _miniKart('Makas',
            _makas != null ? tlBicim.format(_makas) : '—', 'TL fark', MT.altin)),
        const SizedBox(width: 10),
        Expanded(child: _miniKart('Tesis',
            '${_fab.length}', 'fabrika', MT.yazi)),
      ]);

  Widget _miniKart(String baslik, String deger, String alt, Color renk) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MT.kart,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MT.cizgi),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(fontSize: 10.5, color: MT.soluk,
              fontWeight: FontWeight.w600, letterSpacing: .4)),
          const SizedBox(height: 6),
          Text(deger, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: renk)),
          Text(alt, style: const TextStyle(fontSize: 10.5, color: MT.soluk)),
        ]),
      );

  Widget _fabrikaKarti(Fabrika f) {
    final fark = f.ortalamaFark ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => FactoryDetailScreen(fabrika: f),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: f.sira == 1
                    ? const LinearGradient(colors: [MT.turuncu2, MT.turuncu])
                    : null,
                color: f.sira == 1 ? null : const Color(0xFF1E2839),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('${f.sira}', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: f.sira == 1 ? Colors.white : MT.soluk)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.ad, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (f.bolge != null && f.bolge!.isNotEmpty)
                Text(f.bolge!, style: const TextStyle(fontSize: 11.5, color: MT.soluk)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${tlBicim.format(f.fiyat)} TL',
                  style: MT.fiyat(size: 14.5,
                      color: f.sira == 1 ? MT.altin : MT.yazi)),
              Text('${fark >= 0 ? '+' : ''}${tlBicim.format(fark)}',
                  style: MT.fiyat(size: 11, weight: FontWeight.w600,
                      color: fark >= 0 ? MT.yesil : MT.kirmizi)),
            ]),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: MT.soluk, size: 20),
          ]),
        ),
      ),
    );
  }
}
