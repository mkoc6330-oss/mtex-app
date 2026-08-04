import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Firebase yapılandırması koda gömülü — GoogleService-Info.plist /
/// google-services.json paketlenmese bile Firebase güvenle başlar.
/// (Bunlar istemci kimlik değerleridir, gizli anahtar değildir.)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Bu platform için Firebase yapılandırılmadı');
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBeJLdcWBYazlMYuvWZpv5BP2Z7kRGbrWY',
    appId: '1:306103852683:ios:3d471feefd805862393e8e',
    messagingSenderId: '306103852683',
    projectId: 'mtex-metalexchange',
    storageBucket: 'mtex-metalexchange.firebasestorage.app',
    iosBundleId: 'io.metalexchange.mtex',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDsrezSXKuYgpRkjTGQu9rVUdYksyuNWvA',
    appId: '1:306103852683:android:698d8d3997d6472c393e8e',
    messagingSenderId: '306103852683',
    projectId: 'mtex-metalexchange',
    storageBucket: 'mtex-metalexchange.firebasestorage.app',
  );
}
