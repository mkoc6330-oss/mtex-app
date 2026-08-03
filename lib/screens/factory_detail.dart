import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'home.dart' show tlBicim;

class FactoryDetailScreen extends StatefulWidget {
  final Fabrika fabrika;
  final int? kaliteId;
  const FactoryDetailScreen({super.key, required this.fabrika, this.kaliteId});
  @override
  State<FactoryDetailScreen> createState() => _FactoryDetailScreenState();
}

class _FactoryDetailScreenState extends State<FactoryDetailScreen> {
  List<Map<String, dynamic>> _kaliteler = [];
  bool _kaliteYukleniyor = true;

  int? _seciliKaliteId;
  String? _seciliKaliteAd;
  List<Map<String, dynamic>> _seri = [];
  bool _seriYukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final liste = await Api.fabrikaKaliteFiyatlari(widget.fabrika.id);
      if (mounted) {
        setState(() {
          _kaliteler = liste;
          _kaliteYukleniyor = false;
        });
      }
      if (liste.isNotEmpty) {
        final ilk = liste.firstWhere(
          (k) => k['kalite_id'] == widget.kaliteId,
          orElse: () => liste.first,
        );
        await _grafikYukle(ilk['kalite_id'] as int, ilk['kalite'] as String);
      } else if (mounted) {
        setState(() => _seriYukleniyor = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _kaliteYukleniyor = false;
          _seriYukleniyor = false;
        });
      }
    }
  }

  Future<void> _grafikYukle(int kaliteId, String kaliteAd) async {
    setState(() {
      _seciliKaliteId = kaliteId;
      _seciliKaliteAd = kaliteAd;
      _seriYukleniyor = true;
      _seri = [];
    });
    try {
      final j = await Api.gecmis(widget.fabrika.id, gun: 45, kaliteId: kaliteId);
      if (j['ok'] == true) {
        _seri = (j['seri'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _seriYukleniyor = false);
  }

  @override
  Widget build(BuildContext c) {
    final f = widget.fabrika;
    double? ilk, son, degisim;
    if (_seri.length >= 2) {
      ilk = (_seri.first['fiyat'] as num).toDouble();
      son = (_seri.last['fiyat'] as num).toDouble();
      degisim = son - ilk;
    }
    return Scaffold(
      appBar: AppBar(title: Text(f.ad)),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 30), children: [
        Row(children: [
          if (f.bolge != null && f.bolge!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: MT.kart,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: MT.cizgi),
              ),
              child: Text(f.bolge!,
                  style: const TextStyle(fontSize: 12, color: MT.soluk)),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: MT.kart,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: MT.cizgi),
            ),
            child: Text('Sıra ${f.sira}.',
                style: const TextStyle(fontSize: 12, color: MT.soluk)),
          ),
        ]),
        const SizedBox(height: 14),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Alım Fiyatları',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (_kaliteler.isNotEmpty && _kaliteler.first['tarih'] != null)
                Text('${_kaliteler.first['tarih']}',
                    style: const TextStyle(fontSize: 11.5, color: MT.soluk)),
            ]),
            const SizedBox(height: 6),
            const Text('Kaliteye dokun — grafiği o seri için gör',
                style: TextStyle(fontSize: 11.5, color: MT.soluk)),
            const SizedBox(height: 12),
            if (_kaliteYukleniyor)
              const SizedBox(height: 90,
                  child: Center(child: CircularProgressIndicator(color: MT.altin)))
            else if (_kaliteler.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Bu fabrika için fiyat verisi yok',
                    style: TextStyle(color: MT.soluk, fontSize: 13))),
              )
            else
              ..._kaliteler.map(_kaliteSatiri),
          ]),
        )),
        const SizedBox(height: 14),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_seciliKaliteAd == null
                      ? '45 Günlük Seyir'
                      : '$_seciliKaliteAd · 45 Gün',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (degisim != null)
                Text('${degisim >= 0 ? '▲ +' : '▼ '}${tlBicim.format(degisim)} TL',
                    style: MT.fiyat(size: 12.5, weight: FontWeight.w600,
                        color: degisim >= 0 ? MT.yesil : MT.kirmizi)),
            ]),
            const SizedBox(height: 14),
            if (_seriYukleniyor)
              const SizedBox(height: 110,
                  child: Center(child: CircularProgressIndicator(color: MT.altin)))
            else if (_seri.length < 2)
              const SizedBox(height: 90, child: Center(child: Text(
                  'Grafik için yeterli geçmiş veri yok',
                  style: TextStyle(color: MT.soluk, fontSize: 13.5))))
            else ...[
              SizedBox(height: 120, child: CustomPaint(
                  size: Size.infinite, painter: _CizgiGrafik(_seri))),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${_seri.first['tarih']}  ·  ${tlBicim.format(ilk)} TL',
                    style: const TextStyle(fontSize: 11.5, color: MT.soluk)),
                Text('${_seri.last['tarih']}  ·  ${tlBicim.format(son)} TL',
                    style: const TextStyle(fontSize: 11.5, color: MT.soluk)),
              ]),
            ],
          ]),
        )),
      ]),
    );
  }

  Widget _kaliteSatiri(Map<String, dynamic> k) {
    final secili = k['kalite_id'] == _seciliKaliteId;
    final enYuksek = _kaliteler.isNotEmpty && identical(k, _kaliteler.first);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => _grafikYukle(k['kalite_id'] as int, k['kalite'] as String),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MT.bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: secili ? MT.altin : MT.cizgi,
                width: secili ? 1.4 : 1),
          ),
          child: Row(children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k['kalite'] as String, style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
                  if (enYuksek)
                    const Text('en yüksek alım', style: TextStyle(
                        fontSize: 10.5, color: MT.altin)),
                ])),
            Text('${tlBicim.format(k['fiyat'])} TL',
                style: MT.fiyat(size: 14,
                    color: enYuksek ? MT.altin : MT.yazi)),
          ]),
        ),
      ),
    );
  }
}

class _CizgiGrafik extends CustomPainter {
  final List<Map<String, dynamic>> seri;
  _CizgiGrafik(this.seri);

  @override
  void paint(Canvas canvas, Size size) {
    if (seri.length < 2) return;
    final d = seri.map((e) => (e['fiyat'] as num).toDouble()).toList();
    final mn = d.reduce((a, b) => a < b ? a : b);
    final mx = d.reduce((a, b) => a > b ? a : b);
    final ar = (mx - mn) == 0 ? 1.0 : (mx - mn);

    final yol = Path();
    final dolgu = Path();
    for (var i = 0; i < d.length; i++) {
      final x = size.width * i / (d.length - 1);
      final y = size.height - ((d[i] - mn) / ar) * (size.height - 12) - 6;
      if (i == 0) { yol.moveTo(x, y); dolgu.moveTo(x, size.height); dolgu.lineTo(x, y); }
      else { yol.lineTo(x, y); dolgu.lineTo(x, y); }
    }
    dolgu.lineTo(size.width, size.height);
    dolgu.close();

    canvas.drawPath(dolgu, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x33F0B429), Color(0x00F0B429)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    canvas.drawPath(yol, Paint()
      ..color = MT.altin
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _CizgiGrafik o) => o.seri != seri;
}
