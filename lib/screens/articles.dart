import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'article_detail.dart';

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});
  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  List<Makale> _analiz = [], _haber = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final a = await Api.analizler();
      if (a['ok'] == true) {
        _analiz = (a['analizler'] as List).map((e) => Makale.json(e)).toList();
      }
      final h = await Api.haberler();
      if (h['ok'] == true) {
        _haber = (h['haberler'] as List).map((e) => Makale.json(e)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: const Text('Piyasa Analizleri'),
          bottom: TabBar(
            controller: _tc,
            indicatorColor: MT.turuncu,
            labelColor: MT.turuncu,
            unselectedLabelColor: MT.soluk,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'MTEX Analiz'), Tab(text: 'Haberler')],
          ),
        ),
        body: _yukleniyor
            ? const Center(child: CircularProgressIndicator(color: MT.turuncu))
            : TabBarView(controller: _tc, children: [
                _liste(_analiz, 'Analizler hazırlanıyor'),
                _liste(_haber, 'Haber bulunamadı'),
              ]),
      );

  Widget _liste(List<Makale> m, String bosMesaj) => RefreshIndicator(
        color: MT.turuncu, backgroundColor: MT.kart, onRefresh: _yukle,
        child: m.isEmpty
            ? ListView(children: [const SizedBox(height: 140),
                Center(child: Text(bosMesaj, style: const TextStyle(color: MT.soluk)))])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
                itemCount: m.length,
                itemBuilder: (ctx, i) {
                  final a = m[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => Navigator.push(ctx, MaterialPageRoute(
                        builder: (_) => ArticleDetailScreen(id: a.id, baslik: a.baslik))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.baslik, style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, height: 1.35)),
                          if (a.ozet != null && a.ozet!.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(a.ozet!, maxLines: 3, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: MT.soluk, height: 1.45)),
                          ],
                          const SizedBox(height: 9),
                          Row(children: [
                            const Icon(Icons.schedule, size: 12.5, color: MT.soluk),
                            const SizedBox(width: 4),
                            Text(_tarih(a.tarih),
                                style: const TextStyle(fontSize: 11.5, color: MT.soluk)),
                            if (a.kaynak != null && a.kaynak!.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Text('· ${a.kaynak}',
                                  style: const TextStyle(fontSize: 11.5, color: MT.soluk)),
                            ],
                          ]),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      );

  String _tarih(String? t) {
    if (t == null || t.length < 10) return '';
    return '${t.substring(8, 10)}.${t.substring(5, 7)}.${t.substring(0, 4)}';
  }
}
