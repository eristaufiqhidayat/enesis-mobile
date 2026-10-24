import 'package:flutter/material.dart';

/// Warna dari mockup Enesis Mobile (Motoris & Canvassing).
class Warna {
  static const biruTua = Color(0xFF0048A2); // header, menu aktif
  static const aksen = Color(0xFF2C7BE5); // tombol utama, progres
  static const tautan = Color(0xFF1F63C4);
  static const teks = Color(0xFF1B2430);
  static const redup = Color(0xFF5E6E82);
  static const latar = Color(0xFFEDF2F9);
  static const garis = Color(0xFFDDE5EF);
  static const jalur = Color(0xFFE3EAF3); // latar bar progres
  static const biruMuda = Color(0xFFDBE8FB); // chip/menu aktif
  static const biruHeaderTeks = Color(0xFFC9DCF7);
  static const sukses = Color(0xFF1F9D6B);
  static const suksesMuda = Color(0xFFE5F5EE);
  static const peringatan = Color(0xFFE8890C);
  static const peringatanMuda = Color(0xFFFDF1E1);
  static const bahaya = Color(0xFFC6303E);
  static const bahayaMuda = Color(0xFFFBE7E9);
  static const putih = Colors.white;
}

ThemeData temaEnesis() {
  final skema = ColorScheme.fromSeed(seedColor: Warna.aksen, primary: Warna.aksen, surface: Colors.white);

  return ThemeData(
    useMaterial3: true,
    colorScheme: skema,
    scaffoldBackgroundColor: Warna.latar,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Warna.teks),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Warna.teks),
      bodyMedium: TextStyle(fontSize: 14, color: Warna.teks),
      bodySmall: TextStyle(fontSize: 12, color: Warna.redup),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Warna.biruTua,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Warna.aksen,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Warna.tautan,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Warna.garis, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.garis)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.garis)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Warna.biruMuda,
      height: 72,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
