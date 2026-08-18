import 'package:flutter/material.dart';

/// Sitedeki kırmızı "SON DAKİKA" şeridi: solda etiket + yanıp sönen nokta,
/// sağında fabrika fiyat güncellemeleri kesintisiz kayar.
class SonDakikaSeridi extends StatefulWidget {
  final List<String> maddeler;
  const SonDakikaSeridi({super.key, required this.maddeler});

  @override
  State<SonDakikaSeridi> createState() => _SonDakikaSeridiState();
}

class _SonDakikaSeridiState extends State<SonDakikaSeridi>
    with TickerProviderStateMixin {
  late final AnimationController _kayma;
  late final AnimationController _nabiz;
  double _icerikEni = 0;

  static const _yazi = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white);
  static const _bosluk = 34.0;

  @override
  void initState() {
    super.initState();
    _nabiz = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _olcVeBaslat();
  }

  @override
  void didUpdateWidget(covariant SonDakikaSeridi eski) {
    super.didUpdateWidget(eski);
    if (eski.maddeler != widget.maddeler) {
      _kayma.dispose();
      _olcVeBaslat();
    }
  }

  /// Metnin gerçek genişliği ölçülür; kayma hızı sabit (~48 piksel/sn) kalsın
  void _olcVeBaslat() {
    final tp = TextPainter(
      text: TextSpan(text: _metin, style: _yazi),
      textDirection: TextDirection.ltr,
    )..layout();
    _icerikEni = tp.width + _bosluk;
    final saniye = (_icerikEni / 48).clamp(12, 90).round();
    _kayma = AnimationController(
        vsync: this, duration: Duration(seconds: saniye))
      ..repeat();
  }

  String get _metin => widget.maddeler.join('   ·   ');

  @override
  void dispose() {
    _kayma.dispose();
    _nabiz.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Container(
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0xFFC81E2B),
          borderRadius: BorderRadius.all(Radius.circular(9)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          // Sol etiket
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: double.infinity,
            color: const Color(0xFF9E1420),
            child: Row(children: [
              const Text('SON DAKİKA',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900,
                      letterSpacing: .6, color: Colors.white)),
              const SizedBox(width: 6),
              FadeTransition(
                opacity: _nabiz,
                child: Container(width: 7, height: 7,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle)),
              ),
            ]),
          ),
          // Kayan içerik — kesintisiz döngü için metin iki kez yazılır
          Expanded(child: ClipRect(
            child: AnimatedBuilder(
              animation: _kayma,
              builder: (_, __) => Transform.translate(
                offset: Offset(-_kayma.value * _icerikEni, 0),
                child: Row(children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: _bosluk),
                    child: Text(_metin, style: _yazi, maxLines: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: _bosluk),
                    child: Text(_metin, style: _yazi, maxLines: 1),
                  ),
                ]),
              ),
            ),
          )),
        ]),
      );
}
