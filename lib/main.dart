import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/home.dart';
import 'screens/market.dart';
import 'screens/calculator.dart';
import 'screens/articles.dart';
import 'screens/profile.dart';

final yerelBildirim = FlutterLocalNotificationsPlugin();

/// Uygulama kapalıyken gelen bildirim
@pragma('vm:entry-point')
Future<void> _arkaPlanMesaji(RemoteMessage m) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
}

/// Firebase yalnızca Android/iOS'ta kullanılır (masaüstü/web önizlemede atlanır)
bool get _mobilPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.baslat();

  // Arayüz her koşulda açılır; Firebase/bildirim kurulumu arkada yapılır.
  // (Firebase beklenirse ve takılırsa uygulama açılış ekranında kalıyordu.)
  runApp(const MtexApp());

  if (_mobilPlatform) unawaited(_firebaseBaslat());
}

Future<void> _firebaseBaslat() async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_arkaPlanMesaji);
    await _bildirimKur();
  } catch (_) {
    // Bildirim kurulamazsa uygulama bildirimlersiz çalışmaya devam eder
  }
}

Future<void> _bildirimKur() async {
  final fm = FirebaseMessaging.instance;
  await fm.requestPermission(alert: true, badge: true, sound: true);

  const kanal = AndroidNotificationChannel(
    'fiyat', 'Fiyat Güncellemeleri',
    description: 'Fabrikalar fiyat güncellediğinde bildirim',
    importance: Importance.high,
  );
  await yerelBildirim
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(kanal);

  await yerelBildirim.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ));

  // Uygulama açıkken gelen bildirimi göster
  FirebaseMessaging.onMessage.listen((m) {
    final n = m.notification;
    if (n == null) return;
    yerelBildirim.show(
      n.hashCode, n.title, n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails('fiyat', 'Fiyat Güncellemeleri',
            importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
    );
  });

  // iOS: APNs belirteci hazır olmadan abonelik/token işlemleri sessizce
  // başarısız olur — belirteç gelene kadar bekle (en fazla ~20 sn)
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    for (var i = 0; i < 20; i++) {
      try {
        if (await fm.getAPNSToken() != null) break;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // Herkese yayın bildirimleri için konu aboneliği (giriş gerektirmez):
  // sunucu "fiyat" konusuna tek gönderimle tüm cihazlara ulaşır.
  // İlk deneme tutmazsa 10 sn sonra bir kez daha dene.
  try {
    await fm.subscribeToTopic('fiyat');
  } catch (_) {
    await Future.delayed(const Duration(seconds: 10));
    try {
      await fm.subscribeToTopic('fiyat');
    } catch (_) {}
  }

  // Cihaz adresini sunucuya bildir
  try {
    final t = await fm.getToken();
    if (t != null) await Api.cihazKaydet(t, 'mobil');
  } catch (_) {
    await Future.delayed(const Duration(seconds: 10));
    try {
      final t = await fm.getToken();
      if (t != null) await Api.cihazKaydet(t, 'mobil');
    } catch (_) {}
  }
  fm.onTokenRefresh.listen((t2) => Api.cihazKaydet(t2, 'mobil'));
}

class MtexApp extends StatelessWidget {
  const MtexApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'MTEX',
        debugShowCheckedModeBanner: false,
        theme: MT.tema(),
        home: const AnaIskelet(),
        // Klavye açıkken herhangi bir boşluğa dokununca kapanır
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
      );
}

class AnaIskelet extends StatefulWidget {
  const AnaIskelet({super.key});
  @override
  State<AnaIskelet> createState() => _AnaIskeletState();
}

class _AnaIskeletState extends State<AnaIskelet> {
  int _sekme = 0;

  final _ekranlar = const [
    HomeScreen(),
    MarketScreen(),
    CalculatorScreen(),
    ArticlesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext c) => Scaffold(
        body: IndexedStack(index: _sekme, children: _ekranlar),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: MT.kart,
            border: Border(top: BorderSide(color: MT.cizgi)),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: MT.kart,
              indicatorColor: MT.turuncu.withValues(alpha: 0.18),
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
            child: NavigationBar(
              height: 62,
              selectedIndex: _sekme,
              onDestinationSelected: (i) => setState(() => _sekme = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.factory_outlined),
                    selectedIcon: Icon(Icons.factory, color: MT.turuncu),
                    label: 'Fabrikalar'),
                NavigationDestination(
                    icon: Icon(Icons.show_chart_outlined),
                    selectedIcon: Icon(Icons.show_chart, color: MT.turuncu),
                    label: 'Piyasa'),
                NavigationDestination(
                    icon: Icon(Icons.calculate_outlined),
                    selectedIcon: Icon(Icons.calculate, color: MT.turuncu),
                    label: 'Hesapla'),
                NavigationDestination(
                    icon: Icon(Icons.article_outlined),
                    selectedIcon: Icon(Icons.article, color: MT.turuncu),
                    label: 'Analiz'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person, color: MT.turuncu),
                    label: 'Profil'),
              ],
            ),
          ),
        ),
      );
}
