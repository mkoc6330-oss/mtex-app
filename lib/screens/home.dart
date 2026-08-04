import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
  List<Map<String, dynamic>> _fab = [];
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle({bool yenile = false}) async {
    setState(() { _yukleniyor = true; _hata = null; });
    try {
      final liste = await Api.tumFabrikalar(yenile: yenile);
      if (liste.isNotEmpty) {
        _fab = liste;
      } else if (_fab.isEmpty) {
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _whatsapp,
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_rounded),
        label: const Text('WhatsApp',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      appBar: AppBar(
        toolbarHeight: 74,
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset('assets/logo.png', width: 46, height: 46),
          ),
          const SizedBox(width: 12),
          const Text.rich(TextSpan(children: [
            TextSpan(text: 'MTEX ',
                style: TextStyle(fontSize: 26,
                    fontWeight: FontWeight.w800, letterSpacing: .5)),
            TextSpan(text: 'HURDA',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                    letterSpacing: .5, color: MT.altin)),
          ])),
        ]),
        actions: [
          IconButton(onPressed: () => _yukle(yenile: true),
              icon: const Icon(Icons.refresh, color: MT.soluk)),
        ],
      ),
      body: RefreshIndicator(
        color: MT.turuncu,
        backgroundColor: MT.kart,
        onRefresh: () => _yukle(yenile: true),
        child: _yukleniyor && _fab.isEmpty
            ? const Center(child: CircularProgressIndicator(color: MT.turuncu))
            : _hata != null && _fab.isEmpty
                ? _hataGorunumu()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Fabrika Sıralaması · ${_fab.length} tesis',
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w700)),
                      ),
                      for (var i = 0; i < _fab.length; i++)
                        _fabrikaKarti(i, _fab[i]),
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

  Future<void> _whatsapp() async {
    final uri = Uri.parse('https://wa.me/905308632022');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
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

  Widget _fabrikaKarti(int indeks, Map<String, dynamic> m) {
    final f = Fabrika.json(m);
    final sira = indeks + 1;
    final kalite = (m['kalite'] ?? '').toString();
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
                gradient: sira == 1
                    ? const LinearGradient(colors: [MT.turuncu2, MT.turuncu])
                    : null,
                color: sira == 1 ? null : const Color(0xFF1E2839),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('$sira', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: sira == 1 ? Colors.white : MT.soluk)),
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
                      color: sira == 1 ? MT.altin : MT.yazi)),
              if (kalite.isNotEmpty)
                Text(kalite, style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: MT.soluk)),
            ]),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: MT.soluk, size: 20),
          ]),
        ),
      ),
    );
  }
}
