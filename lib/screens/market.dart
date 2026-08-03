import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'home.dart' show tlBicim;

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  Map<String, dynamic>? _v;
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final j = await Api.fiyatlar();
      if (j['ok'] == true) _v = j;
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  String _f(dynamic x, {int ondalik = 0}) {
    if (x == null) return '—';
    final n = (x as num).toDouble();
    return ondalik == 0 ? tlBicim.format(n) : n.toStringAsFixed(ondalik).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext c) {
    final hurda  = _v?['hurda'] as Map<String, dynamic>?;
    final celik  = _v?['celik'] as Map<String, dynamic>?;
    final doviz  = _v?['doviz'] as Map<String, dynamic>?;
    final emtia  = _v?['emtia'] as Map<String, dynamic>?;
    final parite = _v?['parite'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('Piyasa'), actions: [
        IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh, color: MT.soluk)),
      ]),
      body: RefreshIndicator(
        color: MT.turuncu, backgroundColor: MT.kart, onRefresh: _yukle,
        child: _yukleniyor && _v == null
            ? const Center(child: CircularProgressIndicator(color: MT.turuncu))
            : ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 28), children: [
                if (parite != null) _pariteKarti(parite),
                const SizedBox(height: 14),
                _bolum('Çelik Ürünleri', [
                  _kalem('İnşaat Demiri', _f(celik?['insaat_demiri_tl']), 'TL/ton'),
                  _kalem('Kütük', _f(celik?['kutuk_tl']), 'TL/ton'),
                ]),
                _bolum('Hurda', [
                  _kalem('İthal (HMS 1&2)', _f(hurda?['ithal_usd']), 'USD/ton'),
                  _kalem('Yurt İçi', _f(hurda?['yerli_tl']), 'TL/ton'),
                  _kalem('DKP / Sac', _f(hurda?['dkp_tl']), 'TL/ton'),
                ]),
                _bolum('Döviz', [
                  _kalem('USD/TRY', _f(doviz?['usdtry'], ondalik: 2), ''),
                  _kalem('EUR/TRY', _f(doviz?['eurtry'], ondalik: 2), ''),
                  _kalem('GBP/TRY', _f(doviz?['gbptry'], ondalik: 2), ''),
                  _kalem('EUR/USD', _f(doviz?['eurusd'], ondalik: 4), ''),
                ]),
                _bolum('Emtia', [
                  _kalem('Brent Petrol', _f(emtia?['brent'], ondalik: 2), 'USD/varil'),
                  _kalem('WTI', _f(emtia?['wti'], ondalik: 2), 'USD/varil'),
                  _kalem('Bakır', _f(emtia?['bakir_ton']), 'USD/ton'),
                  _kalem('Çinko', _f(emtia?['cinko'], ondalik: 2), ''),
                  _kalem('Kurşun', _f(emtia?['kursun'], ondalik: 2), ''),
                  _kalem('Nikel', _f(emtia?['nikel'], ondalik: 2), ''),
                  _kalem('Kalay', _f(emtia?['kalay'], ondalik: 2), ''),
                  _kalem('Altın', _f(emtia?['altin_ons'], ondalik: 2), 'USD/ons'),
                  _kalem('Gümüş', _f(emtia?['gumus'], ondalik: 2), 'USD/ons'),
                ]),
                if ((emtia?['liste'] as List?)?.isNotEmpty ?? false)
                  _bolum('Diğer Kalemler', [
                    for (final e in (emtia!['liste'] as List))
                      _kalem((e['ad'] ?? '').toString(),
                             (e['deger'] ?? '—').toString(),
                             (e['birim'] ?? '').toString()),
                  ]),
              ]),
      ),
    );
  }

  Widget _pariteKarti(Map<String, dynamic> p) {
    final durum = p['durum'] as String?;
    final fark = p['fark_tl'] as num?;
    Color renk = MT.soluk;
    String metin = 'Veri bekleniyor';
    if (durum == 'ucuz') { renk = MT.yesil; metin = 'İç piyasa ucuz — yükselme eğilimi'; }
    else if (durum == 'pahali') { renk = MT.kirmizi; metin = 'İç piyasa pahalı — gerileme riski'; }
    else if (durum == 'dengeli') { renk = MT.soluk; metin = 'Parite ile dengeli'; }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2436), MT.kart],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MT.cizgi),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('İTHAL PARİTE', style: TextStyle(fontSize: 11, color: MT.soluk,
            letterSpacing: .8, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text(_f(p['parite_tl']), style: const TextStyle(
              fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.5)),
          const SizedBox(width: 6),
          const Text('TL/ton', style: TextStyle(fontSize: 13.5, color: MT.soluk)),
        ]),
        const SizedBox(height: 5),
        Text((p['formul'] ?? '').toString(),
            style: const TextStyle(fontSize: 12, color: MT.soluk)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: renk.withValues(alpha: .3)),
          ),
          child: Text(
            fark != null ? '${fark > 0 ? '+' : ''}${tlBicim.format(fark)} TL · $metin' : metin,
            style: TextStyle(fontSize: 12.5, color: renk, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _bolum(String baslik, List<Widget> cocuklar) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Card(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(baslik, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...cocuklar,
          ]),
        )),
      );

  Widget _kalem(String ad, String deger, String birim) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(ad, style: const TextStyle(fontSize: 14, color: MT.soluk))),
          Text(deger, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (birim.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(birim, style: const TextStyle(fontSize: 11.5, color: MT.soluk)),
          ],
        ]),
      );
}
