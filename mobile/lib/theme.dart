import 'package:flutter/material.dart';

/// Mirrors the TradingView-inspired palette used by the web frontend
/// (see frontend/src/app/globals.css) so both clients feel consistent.
class AppColors {
  static const brand = Color(0xFF2962FF);
  static const gain = Color(0xFF089981);
  static const loss = Color(0xFFF23645);

  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceMuted = Color(0xFFF8F9FD);
  static const lightBorder = Color(0xFFE0E3EB);
  static const lightMutedForeground = Color(0xFF787B86);
  static const lightForeground = Color(0xFF131722);

  static const darkBackground = Color(0xFF131722);
  static const darkSurface = Color(0xFF1E222D);
  static const darkSurfaceMuted = Color(0xFF1A1E27);
  static const darkBorder = Color(0xFF2A2E39);
  static const darkMutedForeground = Color(0xFF868993);
  static const darkForeground = Color(0xFFD1D4DC);
}

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
      primary: AppColors.brand,
      surface: AppColors.lightSurface,
    ),
    cardColor: AppColors.lightSurface,
    dividerColor: AppColors.lightBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightForeground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
      primary: AppColors.brand,
      surface: AppColors.darkSurface,
    ),
    cardColor: AppColors.darkSurface,
    dividerColor: AppColors.darkBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkForeground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

Color changeColor(BuildContext context, double? value) {
  if (value == null) return Theme.of(context).colorScheme.onSurfaceVariant;
  return value >= 0 ? AppColors.gain : AppColors.loss;
}
