import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../theme.dart';

/// MTEX'in kendi haberini uygulama içinde tam metin gösterir.
/// (İçerik MTEX'e ait olduğu için yönlendirme yapılmaz.)
class NewsDetailScreen extends StatefulWidget {
  final int id;
  final String baslik;
  final String? gorsel;
  const NewsDetailScreen(
      {super.key, required this.id, required this.baslik, this.gorsel});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  Map<String, dynamic>? _haber;
  bool _yukleniyor = true;
  bool _hata = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final j = await Api.haber(widget.id);
      if (j['ok'] == true && j['haber'] != null) {
        _haber = (j['haber'] as Map).cast<String, dynamic>();
      } else {
        _hata = true;
      }
    } catch (_) {
      _hata = true;
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  String _tarihMetni() {
    final t = DateTime.tryParse((_haber?['tarih'] ?? '').toString());
    if (t == null) return '';
    return DateFormat('d MMMM y · HH:mm', 'tr').format(t);
  }

  @override
  Widget build(BuildContext c) {
    final gorsel =
        (_haber?['gorsel'] ?? widget.gorsel ?? '').toString();
    final kaynak = (_haber?['kaynak'] ?? 'MTEX').toString();
    final etiketler = (_haber?['etiketler'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haber'),
        actions: [
          IconButton(
            tooltip: 'Tarayıcıda aç',
            icon: const Icon(Icons.open_in_new, size: 20, color: MT.soluk),
            onPressed: () {
              final u = (_haber?['url'] ?? '').toString();
              if (u.isNotEmpty) {
                launchUrl(Uri.parse(u), mode: LaunchMode.inAppBrowserView);
              }
            },
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: MT.altin))
          : _hata
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Haber yüklenemedi. İnternet bağlantınızı '
                      'kontrol edip tekrar deneyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MT.soluk)),
                ))
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (gorsel.isNotEmpty)
                      Image.network(gorsel,
                          height: 190, width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kaynak rozeti — içerik MTEX'e ait
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: MT.altin.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(kaynak.toUpperCase(),
                                style: const TextStyle(fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .7, color: MT.altin)),
                          ),
                          const SizedBox(height: 12),
                          Text((_haber?['baslik'] ?? widget.baslik).toString(),
                              style: const TextStyle(fontSize: 21,
                                  fontWeight: FontWeight.w800, height: 1.28)),
                          const SizedBox(height: 8),
                          Text(_tarihMetni(),
                              style: const TextStyle(
                                  fontSize: 12, color: MT.soluk)),
                          const SizedBox(height: 16),
                          if ((_haber?['ozet'] ?? '').toString().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: MT.kart,
                                borderRadius: BorderRadius.circular(11),
                                border: const Border(
                                    left: BorderSide(color: MT.altin, width: 3)),
                              ),
                              child: Text(_haber!['ozet'].toString(),
                                  style: const TextStyle(fontSize: 14,
                                      height: 1.5, color: Color(0xFFD3DAE6))),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Html(
                            data: (_haber?['icerik_html'] ?? '').toString(),
                            style: {
                              'body': Style(
                                margin: Margins.zero,
                                padding: HtmlPaddings.zero,
                                fontSize: FontSize(14.5),
                                lineHeight: const LineHeight(1.62),
                                color: const Color(0xFFC8D0DC),
                              ),
                              'h2': Style(
                                fontSize: FontSize(17),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                margin: Margins.only(top: 22, bottom: 8),
                              ),
                              'h3': Style(
                                fontSize: FontSize(15.5),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                margin: Margins.only(top: 18, bottom: 6),
                              ),
                              'p': Style(margin: Margins.only(bottom: 12)),
                              'li': Style(margin: Margins.only(bottom: 7)),
                              'strong': Style(color: Colors.white),
                              'a': Style(color: MT.altin),
                              'table': Style(
                                  backgroundColor: MT.kart,
                                  border: Border.all(color: MT.cizgi)),
                              'th': Style(
                                  padding: HtmlPaddings.all(7),
                                  backgroundColor: const Color(0xFF1E2839),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                              'td': Style(padding: HtmlPaddings.all(7)),
                            },
                            onLinkTap: (url, _, __) {
                              if (url != null && url.isNotEmpty) {
                                launchUrl(Uri.parse(url),
                                    mode: LaunchMode.inAppBrowserView);
                              }
                            },
                          ),
                          if (etiketler.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Wrap(spacing: 7, runSpacing: 7, children: [
                              for (final e in etiketler)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: MT.kart,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: MT.cizgi),
                                  ),
                                  child: Text('#$e',
                                      style: const TextStyle(
                                          fontSize: 11, color: MT.soluk)),
                                ),
                            ]),
                          ],
                          const SizedBox(height: 22),
                          const Divider(color: MT.cizgi),
                          const SizedBox(height: 10),
                          const Text('MTEX · metalexchange.io',
                              style: TextStyle(fontSize: 11.5, color: MT.soluk)),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
