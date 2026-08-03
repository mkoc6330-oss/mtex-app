import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtex/theme.dart';

void main() {
  test('MTEX teması koyu ve turuncu vurgulu', () {
    final t = MT.tema();
    expect(t.brightness, Brightness.dark);
    expect(t.colorScheme.primary, MT.turuncu);
  });
}
