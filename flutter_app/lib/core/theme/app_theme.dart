import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // STITCH "BALAD" Exact Colors
  static const Color stitchBackground = Color(0xFF1A1122);
  static const Color stitchSurface = Color(0xFF261933);
  static const Color stitchChips = Color(0xFF362348);
  static const Color stitchTextSecondary = Color(0xFFAD92C9);
  static const Color stitchPrimary = Color(0xFF7F13EC);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: stitchPrimary,
        primary: stitchPrimary,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: stitchPrimary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: stitchPrimary,
        primary: stitchPrimary,
        surface: stitchSurface,
        onSurface: stitchTextSecondary,
      ),
      scaffoldBackgroundColor: stitchBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: stitchBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: stitchTextSecondary,
          fontSize: 16,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          color: stitchTextSecondary,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: stitchBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: stitchSurface,
        selectedItemColor: Colors.white,
        unselectedItemColor: stitchTextSecondary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
