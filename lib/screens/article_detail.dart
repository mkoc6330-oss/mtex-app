import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../api.dart';
import '../theme.dart';

class ArticleDetailScreen extends StatefulWidget {
  final int id;
  final String baslik;
  const ArticleDetailScreen({super.key, required this.id, required this.baslik});
  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  String? _html, _ozet;
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    try {
      final j = await Api.haber(widget.id);
      if (j['ok'] == true) {
        final h = j['haber'] as Map<String, dynamic>;
        _html = h['icerik_html'] as String?;
        _ozet = h['ozet'] as String?;
      }
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Analiz')),
        body: _yukleniyor
            ? const Center(child: CircularProgressIndicator(color: MT.turuncu))
            : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 34), children: [
                Text(widget.baslik, style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800, height: 1.32)),
                if (_ozet != null && _ozet!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: MT.kart,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: MT.cizgi),
                    ),
                    child: Text(_ozet!, style: const TextStyle(
                        fontSize: 14, color: MT.soluk, height: 1.55)),
                  ),
                ],
                const SizedBox(height: 16),
                if (_html != null && _html!.isNotEmpty)
                  Html(data: _html!, style: {
                    'body': Style(color: MT.yazi, fontSize: FontSize(15),
                        lineHeight: LineHeight.number(1.62), margin: Margins.zero),
                    'h2': Style(color: MT.yazi, fontSize: FontSize(18),
                        fontWeight: FontWeight.w700, margin: Margins.only(top: 22, bottom: 8)),
                    'h3': Style(color: MT.yazi, fontSize: FontSize(16),
                        fontWeight: FontWeight.w700, margin: Margins.only(top: 16, bottom: 6)),
                    'p': Style(margin: Margins.only(bottom: 13)),
                    'table': Style(backgroundColor: MT.kart),
                    'th': Style(color: MT.soluk, fontSize: FontSize(13), padding: HtmlPaddings.all(7)),
                    'td': Style(color: MT.yazi, fontSize: FontSize(13.5), padding: HtmlPaddings.all(7)),
                    'li': Style(margin: Margins.only(bottom: 7)),
                  })
                else
                  const Text('İçerik yüklenemedi.', style: TextStyle(color: MT.soluk)),
              ]),
      );
}
