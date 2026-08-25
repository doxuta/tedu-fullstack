/// Hệ thiết kế "Tiệm văn phòng phẩm Sài Gòn 1960" — chuyển thể từ bản web.
library;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Ink2 {
  static const paper = Color(0xFFF1EAD8);
  static const card = Color(0xFFF7F2E3);
  static const panel = Color(0xFFEDE4CD);
  static const ink = Color(0xFF2B2318);
  static const muted = Color(0xFF7A6F5C);
  static const faint = Color(0xFFA39A85);
  static const line = Color(0x292B2318); // rgba(43,35,24,.16)
  static const oxblood = Color(0xFF93392C);
  static const green = Color(0xFF2F5D50);
  static const gold = Color(0xFFB08D3F);
  static const mustard = Color(0xFFC8922A);
  static const navy = Color(0xFF33506B);
  static const espresso = Color(0xFF221B12);
  static const cream = Color(0xFFEFE6CF);
}

ThemeData buildVintageTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Ink2.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Ink2.oxblood,
      primary: Ink2.oxblood,
      secondary: Ink2.green,
      surface: Ink2.card,
      onSurface: Ink2.ink,
    ),
  );
  final body = GoogleFonts.beVietnamProTextTheme(base.textTheme)
      .apply(bodyColor: Ink2.ink, displayColor: Ink2.ink);
  return base.copyWith(
    textTheme: body.copyWith(
      headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 30, fontWeight: FontWeight.w800, color: Ink2.ink),
      headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w700, color: Ink2.ink),
      titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 20, fontWeight: FontWeight.w700, color: Ink2.ink),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Ink2.paper,
      foregroundColor: Ink2.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w800, color: Ink2.ink),
    ),
    dividerColor: Ink2.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFBF7EA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Ink2.ink.withValues(alpha: .30)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Ink2.ink.withValues(alpha: .30)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Ink2.oxblood, width: 1.4),
      ),
      labelStyle: const TextStyle(color: Ink2.muted),
      isDense: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Ink2.oxblood,
        foregroundColor: Ink2.cream,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Ink2.ink,
        side: BorderSide(color: Ink2.ink.withValues(alpha: .45)),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Ink2.espresso,
      contentTextStyle: TextStyle(color: Ink2.cream),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  );
}

String fmtMoney(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b ₫';
}

String fmtDate(String iso) {
  if (iso.length < 10) return iso;
  return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
}

const dayNamesVi = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 0: 'CN'};
