import 'package:fl_chart/fl_chart.dart';
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
  int _gun = 30;
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

  Future<void> _grafikYukle(int kaliteId, String kaliteAd, {int? gun}) async {
    setState(() {
      _seciliKaliteId = kaliteId;
      _seciliKaliteAd = kaliteAd;
      if (gun != null) _gun = gun;
      _seriYukleniyor = true;
      _seri = [];
    });
    try {
      final j =
          await Api.gecmis(widget.fabrika.id, gun: _gun, kaliteId: kaliteId);
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
        if (f.bolge != null && f.bolge!.isNotEmpty) ...[
          Row(children: [
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
          ]),
          const SizedBox(height: 14),
        ],
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text(
                    _seciliKaliteAd == null
                        ? 'Fiyat Seyri'
                        : '$_seciliKaliteAd · Fiyat Seyri',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              if (degisim != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (degisim >= 0 ? MT.yesil : MT.kirmizi)
                        .withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                      '${degisim >= 0 ? '▲ +' : '▼ '}${tlBicim.format(degisim)} TL',
                      style: MT.fiyat(size: 12, weight: FontWeight.w700,
                          color: degisim >= 0 ? MT.yesil : MT.kirmizi)),
                ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              for (final g in const [7, 30, 90]) ...[
                _donemSecici(g),
                const SizedBox(width: 7),
              ],
              const Spacer(),
              if (son != null)
                Text('Son: ${tlBicim.format(son)} TL',
                    style: MT.fiyat(size: 11.5,
                        weight: FontWeight.w600, color: MT.soluk)),
            ]),
            const SizedBox(height: 14),
            if (_seriYukleniyor)
              const SizedBox(height: 190,
                  child: Center(child: CircularProgressIndicator(color: MT.altin)))
            else if (_seri.length < 2)
              const SizedBox(height: 150, child: Center(child: Text(
                  'Bu dönem için yeterli geçmiş veri yok',
                  style: TextStyle(color: MT.soluk, fontSize: 13.5))))
            else
              SizedBox(height: 190, child: _grafik()),
          ]),
        )),
      ]),
    );
  }

  Widget _donemSecici(int g) {
    final secili = _gun == g;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: secili || _seciliKaliteId == null
          ? null
          : () => _grafikYukle(_seciliKaliteId!, _seciliKaliteAd!, gun: g),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: secili ? MT.altin.withValues(alpha: .16) : MT.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: secili ? MT.altin : MT.cizgi),
        ),
        child: Text('$g Gün',
            style: TextStyle(fontSize: 11.5,
                fontWeight: secili ? FontWeight.w800 : FontWeight.w600,
                color: secili ? MT.altin : MT.soluk)),
      ),
    );
  }

  /// "2026-08-15" → "15.08"
  String _kisaTarih(int indeks) {
    final t = (_seri[indeks]['tarih'] ?? '').toString();
    final p = t.split('-');
    return p.length == 3 ? '${p[2]}.${p[1]}' : t;
  }

  Widget _grafik() {
    final d = _seri.map((e) => (e['fiyat'] as num).toDouble()).toList();
    final mn = d.reduce((a, b) => a < b ? a : b);
    final mx = d.reduce((a, b) => a > b ? a : b);
    final pay = (mx - mn) == 0 ? (mx == 0 ? 100 : mx * .01) : (mx - mn) * .18;
    final altSinir = mn - pay, ustSinir = mx + pay;

    final noktalar = [
      for (var i = 0; i < d.length; i++) FlSpot(i.toDouble(), d[i]),
    ];

    return LineChart(
      LineChartData(
        minY: altSinir,
        maxY: ustSinir,
        minX: 0,
        maxX: (d.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (ustSinir - altSinir) / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: (ustSinir - altSinir) / 4,
              getTitlesWidget: (v, meta) {
                if (v <= altSinir || v >= ustSinir) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(tlBicim.format(v.round()),
                      style: MT.fiyat(size: 9.5,
                          weight: FontWeight.w600, color: MT.soluk)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (d.length - 1) / 3 <= 0 ? 1 : (d.length - 1) / 3,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= d.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_kisaTarih(i),
                      style: const TextStyle(fontSize: 9.5, color: MT.soluk)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF232E45),
            tooltipBorder: const BorderSide(color: MT.altin, width: .7),
            tooltipRoundedRadius: 9,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (dokunulan) => [
              for (final n in dokunulan)
                LineTooltipItem(
                  '${_kisaTarih(n.x.round())}\n',
                  const TextStyle(fontSize: 10.5, color: MT.soluk,
                      fontWeight: FontWeight.w600),
                  children: [
                    TextSpan(
                      text: '${tlBicim.format(n.y.round())} TL',
                      style: MT.fiyat(size: 13,
                          weight: FontWeight.w800, color: MT.altin),
                    ),
                  ],
                ),
            ],
          ),
          getTouchedSpotIndicator: (bar, indeksler) => [
            for (final _ in indeksler)
              TouchedSpotIndicatorData(
                const FlLine(color: Color(0x66F0B429), strokeWidth: 1,
                    dashArray: [4, 3]),
                FlDotData(
                  getDotPainter: (s, __, ___, ____) => FlDotCirclePainter(
                    radius: 4.5,
                    color: MT.altin,
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF171D2E),
                  ),
                ),
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: noktalar,
            isCurved: true,
            curveSmoothness: .22,
            preventCurveOverShooting: true,
            barWidth: 2.4,
            color: MT.altin,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              // Yalnızca en düşük, en yüksek ve son nokta işaretlenir
              checkToShowDot: (s, bar) =>
                  s.y == mn || s.y == mx || s.x == (d.length - 1).toDouble(),
              getDotPainter: (s, __, ___, ____) => FlDotCirclePainter(
                radius: s.x == (d.length - 1).toDouble() ? 3.6 : 2.8,
                color: s.y == mx
                    ? MT.yesil
                    : (s.y == mn ? MT.kirmizi : MT.altin),
                strokeWidth: 1.6,
                strokeColor: const Color(0xFF171D2E),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x40F0B429), Color(0x00F0B429)],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
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
