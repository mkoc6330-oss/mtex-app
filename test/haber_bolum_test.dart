import 'package:flutter_test/flutter_test.dart';
import 'package:mtex/api.dart';

void main() {
  String bolum(String b, [String o = '']) => Api.haberBolumu(b, o);

  test('hurda ve metal haberleri dogru bolume gider', () {
    expect(bolum("Türkiye'nin ham çelik üretimi ağustosta azaldı"),
        'Hurda & Metal');
    expect(bolum('LME bakır stok düşüşüyle yükseldi'), 'Hurda & Metal');
    expect(bolum('Hurda ithalatı arttı'), 'Hurda & Metal');
  });

  test('finans, enerji ve tarim ayrisir', () {
    expect(bolum('Merkez Bankası faiz kararını açıkladı'), 'Finans');
    expect(bolum('Brent petrol 72 doları aştı'), 'Enerji');
    expect(bolum('Buğday hasadı rekor kırdı'), 'Tarım & Gıda');
  });

  test('kisa kaliplar kelime icinde eslesmez', () {
    // "ons" sponsor icinde, "bal" balkon icinde, "lme" filmde gecmemeli
    expect(bolum('Turnuvaya yeni sponsor bulundu'), isNot('Finans'));
    expect(bolum('Balkon kullanımına yeni kural'), isNot('Tarım & Gıda'));
    expect(bolum('Belgesel film gösterimi yapıldı'), isNot('Hurda & Metal'));
  });

  test('eslesmeyen haber Gundem olur', () {
    expect(bolum('Kültür festivali başladı'), 'Gündem');
  });

  test('sira onceligi: celik gecen haber finansa dusmez', () {
    expect(bolum('Çelik üreticisinin hissesi borsada yükseldi'),
        'Hurda & Metal');
  });
}
