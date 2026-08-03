import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'home.dart' show tlBicim;

final tonBicim = NumberFormat('#,##0.###', 'tr_TR');

/// Eksper Hesabı — fabrikanın eksper raporundaki kg'lar kalite kalite girilir,
/// her satır o fabrikanın ton fiyatıyla çarpılır.
/// Sonuç: toplam tutar / toplam tonaj = ortalama fiyat.
/// (Hurda vergiden muaftır; hesapta yalnızca fiyat × tonaj vardır.)
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  List<Fabrika> _fabrikalar = [];
  Fabrika? _secili;

  List<Map<String, dynamic>> _kaliteler = [];
  final Map<int, TextEditingController> _kg = {};
  bool _fabYukleniyor = true;
  bool _kaliteYukleniyor = false;

  @override
  void initState() {
    super.initState();
    _fabrikalariYukle();
  }

  @override
  void dispose() {
    for (final c in _kg.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fabrikalariYukle() async {
    try {
      final f = await Api.fabrikalar();
      if (f['ok'] == true) {
        _fabrikalar =
            (f['fabrikalar'] as List).map((e) => Fabrika.json(e)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _fabYukleniyor = false);
    if (_fabrikalar.isNotEmpty) _fabrikaSec(_fabrikalar.first);
  }

  Future<void> _fabrikaSec(Fabrika f) async {
    setState(() {
      _secili = f;
      _kaliteYukleniyor = true;
      _kaliteler = [];
    });
    try {
      final liste = await Api.fabrikaKaliteFiyatlari(f.id);
      for (final k in liste) {
        _kg.putIfAbsent(
            k['kalite_id'] as int, () => TextEditingController());
      }
      _kaliteler = liste;
    } catch (_) {}
    if (mounted) setState(() => _kaliteYukleniyor = false);
  }

  double _kgDegeri(int kaliteId) {
    final t = _kg[kaliteId]?.text ?? '';
    if (t.trim().isEmpty) return 0;
    return double.tryParse(
            t.replaceAll('.', '').replaceAll(' ', '').replaceAll(',', '.')) ??
        0;
  }

  @override
  Widget build(BuildContext c) {
    double toplamKg = 0, toplamTutar = 0;
    for (final k in _kaliteler) {
      final kg = _kgDegeri(k['kalite_id'] as int);
      toplamKg += kg;
      toplamTutar += kg / 1000 * (k['fiyat'] as num);
    }
    final toplamTon = toplamKg / 1000;
    final ortalama = toplamTon > 0 ? toplamTutar / toplamTon : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Eksper Hesabı')),
      body: _fabYukleniyor
          ? const Center(child: CircularProgressIndicator(color: MT.altin))
          : _fabrikalar.isEmpty
              ? const Center(child: Text('Fabrika verisi alınamadı',
                  style: TextStyle(color: MT.soluk)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _secili?.id,
                      decoration: const InputDecoration(labelText: 'Fabrika'),
                      dropdownColor: MT.kart,
                      items: _fabrikalar
                          .map((f) => DropdownMenuItem(
                              value: f.id,
                              child: Text(f.ad, style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w600))))
                          .toList(),
                      onChanged: (id) {
                        final f = _fabrikalar.where((x) => x.id == id).firstOrNull;
                        if (f != null) _fabrikaSec(f);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('Eksper Raporu — kg gir',
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                    ),
                    if (_kaliteYukleniyor)
                      const SizedBox(height: 120,
                          child: Center(
                              child: CircularProgressIndicator(color: MT.altin)))
                    else if (_kaliteler.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text(
                            'Bu fabrika için kalite fiyatı bulunamadı',
                            style: TextStyle(color: MT.soluk, fontSize: 13))),
                      )
                    else ...[
                      ..._kaliteler.map(_kaliteSatiri),
                      const SizedBox(height: 12),
                      _ozetKarti(toplamTon, toplamTutar, ortalama),
                    ],
                  ],
                ),
    );
  }

  Widget _kaliteSatiri(Map<String, dynamic> k) {
    final id = k['kalite_id'] as int;
    final kg = _kgDegeri(id);
    final tutar = kg / 1000 * (k['fiyat'] as num);
    final bos = kg <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: MT.kart,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bos ? MT.cizgi : MT.altin.withValues(alpha: .45)),
        ),
        child: Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k['kalite'] as String, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${tlBicim.format(k['fiyat'])} TL/ton',
                    style: MT.fiyat(size: 10.5,
                        weight: FontWeight.w500, color: MT.soluk)),
              ])),
          SizedBox(
            width: 92,
            child: TextField(
              controller: _kg[id],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textAlign: TextAlign.right,
              style: MT.fiyat(size: 13.5),
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: 'kg',
                suffixStyle: TextStyle(fontSize: 11, color: MT.soluk),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 86,
            child: Text(bos ? '—' : tlBicim.format(tutar),
                textAlign: TextAlign.right,
                style: MT.fiyat(size: 13,
                    color: bos ? MT.soluk : MT.yazi)),
          ),
        ]),
      ),
    );
  }

  Widget _ozetKarti(double ton, double tutar, double ortalama) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: MT.altinGrad,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          _ozetSatir('Toplam tonaj', '${tonBicim.format(ton)} ton'),
          const SizedBox(height: 6),
          _ozetSatir('Toplam tutar', '${tlBicim.format(tutar)} TL'),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x33131722))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('ORTALAMA FİYAT', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    letterSpacing: .8, color: MT.altinUstu)),
                Text('${tlBicim.format(ortalama)} TL/ton',
                    style: MT.fiyat(size: 19, weight: FontWeight.w800,
                        color: MT.altinUstu)),
              ],
            ),
          ),
        ]),
      );

  Widget _ozetSatir(String s, String d) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(s, style: const TextStyle(fontSize: 12.5,
              fontWeight: FontWeight.w700, color: MT.altinUstu)),
          Text(d, style: MT.fiyat(size: 13.5, color: MT.altinUstu)),
        ],
      );
}
