import 'package:flutter_test/flutter_test.dart';
import 'package:mtex/surum.dart';

void main() {
  test('magazadaki surum daha yeniyse true', () {
    expect(SurumKontrol.yeniMi('1.0.2', '1.0.1'), isTrue);
    expect(SurumKontrol.yeniMi('1.1.0', '1.0.9'), isTrue);
    expect(SurumKontrol.yeniMi('2.0.0', '1.9.9'), isTrue);
    // Metin siralamasi "1.0.10" < "1.0.9" derdi; sayi sayi bakilmali
    expect(SurumKontrol.yeniMi('1.0.10', '1.0.9'), isTrue);
    expect(SurumKontrol.yeniMi('1.1', '1.0.5'), isTrue);
  });

  test('ayni veya eski surumde uyari cikmaz', () {
    expect(SurumKontrol.yeniMi('1.0.1', '1.0.1'), isFalse);
    expect(SurumKontrol.yeniMi('1.0.1', '1.0.2'), isFalse);
    expect(SurumKontrol.yeniMi('1.0.9', '1.0.10'), isFalse);
    expect(SurumKontrol.yeniMi('1.0.1', '1.0.1+16'), isFalse);
    expect(SurumKontrol.yeniMi('', '1.0.1'), isFalse);
  });
}
