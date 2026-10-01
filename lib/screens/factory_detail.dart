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
  /// kalite_id → son fiyat değişimi (+ yükseliş / − düşüş)
  Map<int, num> _degisim = {};

  int? _seciliKaliteId;
  String? _seciliKaliteAd;
  /// Grafik tek dönem gösterir: son 90 gün
  static const _gun = 90;
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
        // Kalite rozetleri için son değişimler arka planda hesaplanır
        _degisimleriYukle(liste);
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

  Future<void> _degisimleriYukle(List<Map<String, dynamic>> liste) async {
    try {
      final d = await Api.kaliteDegisimleri(widget.fabrika.id,
          liste.map((k) => k['kalite_id'] as int).toList());
      if (mounted) setState(() => _degisim = d);
    } catch (_) {}
  }

  Future<void> _grafikYukle(int kaliteId, String kaliteAd) async {
    setState(() {
      _seciliKaliteId = kaliteId;
      _seciliKaliteAd = kaliteAd;
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: MT.altin.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MT.altin),
                ),
                child: const Text('Son 90 Gün',
                    style: TextStyle(fontSize: 11.5,
                        fontWeight: FontWeight.w800, color: MT.altin)),
              ),
              const SizedBox(width: 9),
              if (_degisimSayisi > 0)
                Text('$_degisimSayisi değişim',
                    style: const TextStyle(fontSize: 11.5, color: MT.soluk)),
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

  /// Fiyatın bir önceki güne göre değiştiği günler: indeks → fark.
  /// Fabrika fiyatı her gün değişmediği için seri basamaklı ilerler;
  /// grafikte yalnızca bu günler işaretlenir.
  Map<int, double> get _degisimGunleri {
    final g = <int, double>{};
    for (var i = 1; i < _seri.length; i++) {
      final onceki = (_seri[i - 1]['fiyat'] as num).toDouble();
      final simdi = (_seri[i]['fiyat'] as num).toDouble();
      if (simdi != onceki) g[i] = simdi - onceki;
    }
    return g;
  }

  int get _degisimSayisi => _degisimGunleri.length;

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
    final degisimler = _degisimGunleri;
    final sonIndeks = (d.length - 1).toDouble();

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
        // Değişim günleri dikey kesikli çizgiyle de belirtilir
        extraLinesData: ExtraLinesData(
          verticalLines: [
            for (final i in degisimler.keys)
              VerticalLine(
                x: i.toDouble(),
                color: (degisimler[i]! > 0 ? MT.yesil : MT.kirmizi)
                    .withValues(alpha: .22),
                strokeWidth: 1,
                dashArray: const [3, 3],
              ),
          ],
        ),
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
                    if (degisimler[n.x.round()] != null)
                      TextSpan(
                        text: '\n'
                            '${degisimler[n.x.round()]! > 0 ? '▲ +' : '▼ '}'
                            '${tlBicim.format(degisimler[n.x.round()]!.round())}'
                            ' TL',
                        style: MT.fiyat(
                            size: 11,
                            weight: FontWeight.w700,
                            color: degisimler[n.x.round()]! > 0
                                ? MT.yesil
                                : MT.kirmizi),
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
              // Fiyatın değiştiği günler ve son gün işaretlenir
              checkToShowDot: (s, bar) =>
                  degisimler.containsKey(s.x.round()) || s.x == sonIndeks,
              getDotPainter: (s, __, ___, ____) {
                final fark = degisimler[s.x.round()];
                final renk = fark == null
                    ? MT.altin
                    : (fark > 0 ? MT.yesil : MT.kirmizi);
                return FlDotCirclePainter(
                  radius: s.x == sonIndeks ? 4.2 : 3.4,
                  color: renk,
                  strokeWidth: 1.8,
                  strokeColor: const Color(0xFF171D2E),
                );
              },
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

  /// Son fiyat değişimi: yükseliş yeşil ▲, düşüş kırmızı ▼.
  /// Fiyat hiç değişmediyse (fark 0) soluk "sabit" rozeti gösterilir —
  /// her kalitenin durumu görünsün, boş kalan satır olmasın.
  Widget _degisimRozeti(num fark) {
    if (fark == 0) {
      return Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
        decoration: BoxDecoration(
          color: MT.bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: MT.cizgi),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.remove_rounded, size: 11.5, color: MT.soluk),
          SizedBox(width: 3),
          Text('sabit',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: MT.soluk)),
        ]),
      );
    }
    final artis = fark > 0;
    final renk = artis ? MT.yesil : MT.kirmizi;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: renk.withValues(alpha: .28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(artis ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 11.5, color: renk),
        const SizedBox(width: 2),
        Text('${artis ? '+' : '−'}${tlBicim.format(fark.abs())} TL',
            style: MT.fiyat(size: 11, weight: FontWeight.w700, color: renk)),
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
            // Değişim rozeti kalite adı ile fiyatın arasında durur
            if (_degisim[k['kalite_id']] != null) ...[
              _degisimRozeti(_degisim[k['kalite_id']]!),
              const SizedBox(width: 11),
            ],
            Text('${tlBicim.format(k['fiyat'])} TL',
                style: MT.fiyat(size: 14,
                    color: enYuksek ? MT.altin : MT.yazi)),
          ]),
        ),
      ),
    );
  }
}
