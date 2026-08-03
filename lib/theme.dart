import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MTEX "Altın & Çelik" teması — logo ile aynı kimlik:
/// koyu lacivert zemin, altın degrade vurgu, çelik grisi nötrler.
/// Not: `turuncu` adı geriye dönük uyumluluk için korunuyor; değeri artık altın.
class MT {
  static const bg      = Color(0xFF0E1220);
  static const kart    = Color(0xFF171D2E);
  static const cizgi   = Color(0xFF232C42);
  static const yazi    = Color(0xFFECF0F8);
  static const soluk   = Color(0xFF94A0B5);
  static const turuncu = Color(0xFFF0B429); // altın
  static const turuncu2= Color(0xFFD97706); // koyu altın
  static const yesil   = Color(0xFF4ADE80);
  static const kirmizi = Color(0xFFF87171);

  static const altin     = turuncu;
  static const altinKoyu = turuncu2;
  static const altinAcik = Color(0xFFFBD34D);

  /// Hero kartı, 1. sıra rozeti gibi vurgu yüzeyleri için
  static const altinGrad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [altinAcik, altinKoyu],
  );

  /// Altın zemin üzerindeki metin rengi
  static const altinUstu = Color(0xFF131722);

  /// Fiyatlar için mono, hizalı rakamlar (IBM Plex Mono)
  static TextStyle fiyat({
    double size = 15,
    FontWeight weight = FontWeight.w700,
    Color color = yazi,
    double? letterSpacing,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData tema() {
    final base = ThemeData.dark(useMaterial3: true);
    final metin = GoogleFonts.manropeTextTheme(base.textTheme)
        .apply(bodyColor: yazi, displayColor: yazi);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      primaryColor: altin,
      colorScheme: base.colorScheme.copyWith(
        primary: altin, secondary: altin, surface: kart,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg, elevation: 0, centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
            color: yazi, fontSize: 18, fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: kart, elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: cizgi),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: kart,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cizgi),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cizgi),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: altin, width: 1.5),
        ),
        labelStyle: GoogleFonts.manrope(color: soluk),
      ),
      textTheme: metin,
      dividerColor: cizgi,
    );
  }
}
