import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/news_detail.dart';
import '../theme.dart';

/// Web sitesindeki haber kartının uygulama karşılığı:
/// üstte 16:9 görsel, altında altın renkli kaynak künyesi, kalın başlık
/// ve tarih. `kompakt` biçiminde görsel sola alınır (liste satırı).
class HaberKarti extends StatelessWidget {
  final Map<String, dynamic> haber;
  final bool kompakt;
  const HaberKarti({super.key, required this.haber, this.kompakt = false});

  @override
  Widget build(BuildContext c) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => habereGit(c, haber),
          child: kompakt ? _satir() : _dikey(),
        ),
      );

  Widget _dikey() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: AspectRatio(
                  aspectRatio: 16 / 9, child: haberGorseli(haber['gorsel'])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kunye(),
                const SizedBox(height: 7),
                Text((haber['baslik'] ?? '').toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.33)),
                const SizedBox(height: 8),
                _tarih(),
              ],
            ),
          ),
        ],
      );

  Widget _satir() => Padding(
        padding: const EdgeInsets.all(9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
                width: 96, height: 72, child: haberGorseli(haber['gorsel'])),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kunye(),
                const SizedBox(height: 5),
                Text((haber['baslik'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.33)),
                const SizedBox(height: 6),
                _tarih(),
              ],
            ),
          ),
        ]),
      );

  /// Lisanslı ajans içeriğinde künye zorunlu
  Widget _kunye() => Text(
        (haber['kaynak'] ?? 'MTEX').toString().toUpperCase(),
        style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
            color: MT.altin),
      );

  Widget _tarih() => Text(haberZamani(haber['tarih']),
      style: const TextStyle(fontSize: 11.5, color: MT.soluk));
}

/// Yerel önizleme derlemelerinde görseller vekil üzerinden çekilir
/// (--dart-define=GORSEL_PROXY=…). Yayında boştur, hiçbir etkisi olmaz.
const _gorselVekil = String.fromEnvironment('GORSEL_PROXY');

String haberGorselAdresi(String url) =>
    _gorselVekil.isEmpty || url.isEmpty ? url : '$_gorselVekil$url';

Widget haberGorseli(Object? url) {
  final u = (url ?? '').toString();
  if (u.isEmpty) return const _GorselYok();
  return Image.network(haberGorselAdresi(u),
      fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _GorselYok());
}

class _GorselYok extends StatelessWidget {
  const _GorselYok();
  @override
  Widget build(BuildContext c) => Container(
        color: const Color(0xFF1E2839),
        alignment: Alignment.center,
        child: const Icon(Icons.newspaper_rounded, size: 26, color: MT.soluk),
      );
}

/// "32 dk önce" / "4 saat önce" / "28.09.2026"
String haberZamani(Object? tarih) {
  final t = tarih is DateTime ? tarih : DateTime.tryParse('${tarih ?? ''}');
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'az önce';
  if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
  if (d.inHours < 24) return '${d.inHours} saat önce';
  if (d.inDays < 7) return '${d.inDays} gün önce';
  return DateFormat('dd.MM.yyyy').format(t);
}

/// MTEX sayfasındaki haber (id'si var) uygulama içinde tam metin okunur;
/// dış bağlantı uygulamadan çıkmadan tarayıcı görünümünde açılır.
void habereGit(BuildContext c, Map<String, dynamic> h) {
  if (h['id'] != null) {
    Navigator.push(
        c,
        MaterialPageRoute(
          builder: (_) => NewsDetailScreen(
            id: h['id'] as int,
            baslik: (h['baslik'] ?? '').toString(),
            gorsel: h['gorsel'] as String?,
          ),
        ));
    return;
  }
  haberBaglantisiniAc((h['link'] ?? '').toString());
}

Future<void> haberBaglantisiniAc(String url) async {
  if (url.isEmpty) return;
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
