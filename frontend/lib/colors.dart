import 'package:flutter/material.dart';

// 1. Định nghĩa bảng màu
class AgriTechColors {
  static const Color primary = Color(0xFF154212);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF2D5A27);
  static const Color onPrimaryContainer = Color(0xFF9DD090);

  static const Color secondary = Color(0xFF7A5649);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFDCDBC);
  static const Color onSecondaryContainer = Color(0xFF795548);

  static const Color surface = Color(0xFFFCF9F8);
  static const Color onSurface = Color(0xFF1B1C1C);
  static const Color background = Color(0xFFFCF9F8);
  static const Color error = Color(0xFFBA1A1A);

  // Dark Mode colors
  static const Color darkBackground = Color(0xFF1B1C1C);
  static const Color darkSurface = Color(0xFF2C2C2C);
  static const Color darkPrimary = Color(0xFFA1D494);
  static const Color darkOnPrimary = Color(0xFF002201);
  static const Color darkSecondary = Color(0xFFEBBCAC);
}

// 2. Định nghĩa AppTheme để main.dart sử dụng
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AgriTechColors.primary,
        secondary: AgriTechColors.secondary,
        surface: AgriTechColors.surface,
        error: AgriTechColors.error,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AgriTechColors.darkPrimary,
        secondary: AgriTechColors.darkSecondary,
        surface: AgriTechColors.darkSurface,
      ),
    );
  }
}
