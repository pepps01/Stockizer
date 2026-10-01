import 'package:flutter/material.dart';

/// The web frontend's colour tokens (frontend/src/app/globals.css): brand
/// indigo, gain green, loss red and hold orange for signals. Widgets read them
/// through `context.palette` so the dark variant stays consistent.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.foreground,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.mutedForeground,
    required this.brand,
    required this.brandSoft,
    required this.brandForeground,
    required this.gain,
    required this.gainSoft,
    required this.loss,
    required this.lossSoft,
    required this.hold,
    required this.holdSoft,
  });

  final Color background;
  final Color foreground;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color mutedForeground;
  final Color brand;
  final Color brandSoft;
  final Color brandForeground;
  final Color gain;
  final Color gainSoft;
  final Color loss;
  final Color lossSoft;
  final Color hold;
  final Color holdSoft;

  static const light = AppPalette(
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF131722),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F3F9),
    border: Color(0xFFE3E6EF),
    mutedForeground: Color(0xFF6B7080),
    brand: Color(0xFF4F46E5),
    brandSoft: Color(0xFFEEF0FF),
    brandForeground: Color(0xFFFFFFFF),
    gain: Color(0xFF089981),
    gainSoft: Color(0xFFE6F5F2),
    loss: Color(0xFFF23645),
    lossSoft: Color(0xFFFDECEE),
    hold: Color(0xFFE38A00),
    holdSoft: Color(0xFFFFF4E0),
  );

  static const dark = AppPalette(
    background: Color(0xFF0F1117),
    foreground: Color(0xFFE6E8EF),
    surface: Color(0xFF171A23),
    surfaceMuted: Color(0xFF1F2330),
    border: Color(0xFF2A2F3D),
    mutedForeground: Color(0xFF9096A8),
    brand: Color(0xFF6D66F2),
    brandSoft: Color(0xFF23244A),
    brandForeground: Color(0xFFFFFFFF),
    gain: Color(0xFF22AB94),
    gainSoft: Color(0xFF10302B),
    loss: Color(0xFFF7525F),
    lossSoft: Color(0xFF3A1A1F),
    hold: Color(0xFFF0A030),
    holdSoft: Color(0xFF3A2A10),
  );

  /// Green / red / muted for a signed change.
  Color change(num? value) {
    if (value == null || value == 0) return mutedForeground;
    return value > 0 ? gain : loss;
  }

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: mix(background, other.background),
      foreground: mix(foreground, other.foreground),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      border: mix(border, other.border),
      mutedForeground: mix(mutedForeground, other.mutedForeground),
      brand: mix(brand, other.brand),
      brandSoft: mix(brandSoft, other.brandSoft),
      brandForeground: mix(brandForeground, other.brandForeground),
      gain: mix(gain, other.gain),
      gainSoft: mix(gainSoft, other.gainSoft),
      loss: mix(loss, other.loss),
      lossSoft: mix(lossSoft, other.lossSoft),
      hold: mix(hold, other.hold),
      holdSoft: mix(holdSoft, other.holdSoft),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

ThemeData buildLightTheme() => _buildTheme(AppPalette.light, Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(AppPalette.dark, Brightness.dark);

ThemeData _buildTheme(AppPalette p, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.brand,
    brightness: brightness,
    primary: p.brand,
    onPrimary: p.brandForeground,
    surface: p.surface,
    onSurface: p.foreground,
    onSurfaceVariant: p.mutedForeground,
    outline: p.border,
    outlineVariant: p.border,
    error: p.loss,
  );
  final radius = BorderRadius.circular(10);
  final buttonShape = RoundedRectangleBorder(borderRadius: radius);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.border,
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(color: p.foreground, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.border)),
    ),
    dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.brand, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.brand,
        foregroundColor: p.brandForeground,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.foreground,
        padding: buttonPadding,
        shape: buttonShape,
        side: BorderSide(color: p.border),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.brand)),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.brandSoft,
      side: BorderSide(color: p.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: p.foreground, fontSize: 13),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.brandSoft,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? p.brand : p.mutedForeground),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? p.brand : p.mutedForeground,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.brand,
      unselectedLabelColor: p.mutedForeground,
      indicatorColor: p.brand,
      dividerColor: p.border,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
