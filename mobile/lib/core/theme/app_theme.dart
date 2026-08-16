import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Colors based on design_guidelines.json
  static const Color primary = Color(0xFF166534); // Deep Forest Green
  static const Color secondary = Color(0xFFF2F0E9); // Warm Sand / Bone-white
  static const Color accent = Color(0xFFE27B58); // Terracotta
  static const Color background = Color(0xFFFAFAFA);
  static const Color foreground = Color(0xFF0A0A0A);
  static const Color cardBg = Colors.white;
  static const Color mutedText = Color(0xFF6B6559); // Warmer gray

  static ThemeData get lightTheme {
    final baseTheme = ThemeData.light();

    return baseTheme.copyWith(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        background: background,
        surface: cardBg,
        onPrimary: Colors.white,
        onSecondary: foreground,
        onBackground: foreground,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardTheme(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x0D000000)), // 5% black border
        ),
      ),
      textTheme: GoogleFonts.dmSansTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
        displayMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        displaySmall: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        titleLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: foreground,
        ),
        titleMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: foreground,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: foreground,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: foreground,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontSize: 12,
          color: mutedText,
        ),
      ),
      buttonTheme: const ButtonThemeData(
        buttonColor: primary,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFE0DCD3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFE0DCD3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: GoogleFonts.dmSans(color: mutedText),
        floatingLabelStyle: GoogleFonts.dmSans(color: primary),
      ),
    );
  }
}
