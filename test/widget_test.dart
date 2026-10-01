import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mtex/theme.dart';

void main() {
  // MT.tema() google_fonts kullaniyor; bu da varlik yukleyici icin
  // baglantinin kurulmus olmasini istiyor. Ayrica test ortaminda ag
  // yok, yazi tipi indirilmeye calisilmasin.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('MTEX teması koyu ve turuncu vurgulu', () {
    final t = MT.tema();
    expect(t.brightness, Brightness.dark);
    expect(t.colorScheme.primary, MT.turuncu);
  });
}
