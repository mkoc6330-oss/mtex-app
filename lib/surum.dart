import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'main.dart' show yerelBildirim, navigatorKey;
import 'theme.dart';

/// Mağazada yeni sürüm varsa kullanıcıyı uyarır.
///
/// İki yol birlikte çalışır:
///  • Uygulama açıkken: ekranda "Yeni sürüm hazır" penceresi.
///  • Pencere gösterilemiyorsa: bildirim merkezine düşen yerel bildirim.
/// Sunucu ayrıca "surum" konusuna tek gönderimle uygulamayı hiç açmayan
/// kullanıcılara da ulaşabilir (abonelik main.dart'ta yapılır).
class SurumKontrol {
  static const _atlananAnahtar = 'guncelleme_atlanan';
  static const _sorulanAnahtar = 'guncelleme_sorulan';
  static const _bildirimId = 90001;

  /// Günde bir kereden sık sorulmaz; kullanıcı "Daha sonra" derse o sürüm
  /// bir daha gösterilmez.
  static Future<void> kontrolEt() async {
    if (kIsWeb) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : null;
    if (platform == null) return;

    try {
      final sp = await SharedPreferences.getInstance();
      final sonSoru = sp.getInt(_sorulanAnahtar) ?? 0;
      final simdi = DateTime.now().millisecondsSinceEpoch;
      if (simdi - sonSoru < const Duration(hours: 24).inMilliseconds) return;

      final bilgi = await Api.magazaSurumu(platform);
      if (bilgi == null) return;
      final magazaSurum = bilgi['surum'] ?? '';
      if (magazaSurum.isEmpty) return;

      final mevcut = (await PackageInfo.fromPlatform()).version;
      if (!yeniMi(magazaSurum, mevcut)) return;
      if (sp.getString(_atlananAnahtar) == magazaSurum) return;

      await sp.setInt(_sorulanAnahtar, simdi);
      final gosterildi = await _pencere(magazaSurum, bilgi['url'] ?? '');
      if (!gosterildi) await _bildirim(magazaSurum, bilgi['url'] ?? '');
    } catch (_) {
      // Sürüm kontrolü uygulamanın çalışmasını engellemez
    }
  }

  /// "1.0.10" > "1.0.9" doğru karşılaştırılsın diye sayı sayı bakılır.
  @visibleForTesting
  static bool yeniMi(String magaza, String mevcut) {
    List<int> ayir(String s) => s
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .toList();
    final a = ayir(magaza), b = ayir(mevcut);
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Pencere gösterilebildiyse true döner.
  static Future<bool> _pencere(String surum, String url) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return false;
    final sonuc = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        backgroundColor: MT.kart,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: MT.turuncu.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.system_update_rounded,
                color: MT.turuncu, size: 20),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text('Yeni sürüm hazır',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ]),
        content: Text(
          'MTEX $surum yayınlandı. Yeni özellikler ve düzeltmeler için '
          'uygulamayı güncelleyin.',
          style: const TextStyle(fontSize: 14, height: 1.5, color: MT.soluk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Daha sonra',
                style: TextStyle(color: MT.soluk)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MT.turuncu),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );

    if (sonuc == true) {
      await magazayiAc(url);
    } else {
      // Bu sürüm bir daha sorulmaz
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_atlananAnahtar, surum);
    }
    return true;
  }

  static Future<void> _bildirim(String surum, String url) async {
    try {
      await yerelBildirim.show(
        id: _bildirimId,
        title: 'MTEX $surum yayında',
        body: 'Yeni özellikler için uygulamayı güncelleyin.',
        payload: jsonEncode({'tur': 'guncelleme', 'url': url}),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
              'guncelleme', 'Uygulama Güncellemeleri',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  static Future<void> magazayiAc(String url) async {
    final hedef = url.isNotEmpty
        ? url
        : (defaultTargetPlatform == TargetPlatform.iOS
            ? Api.appStoreUrl
            : Api.playStoreUrl);
    try {
      await launchUrl(Uri.parse(hedef),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
