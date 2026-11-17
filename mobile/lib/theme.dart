import 'package:flutter/material.dart';

/// "Quiet Ledger" — the same tokens as frontend/src/app/globals.css: ink on
/// white, one indigo accent, and colour spent only on meaning (gain green,
/// loss red, hold amber). Widgets read them through `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.foreground,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.mutedForeground,
    required this.ink,
    required this.inkForeground,
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

  /// Primary buttons, selected chips and tabs: near-black in light mode,
  /// near-white in dark mode.
  final Color ink;
  final Color inkForeground;
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
    foreground: Color(0xFF101418),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F4F1),
    border: Color(0xFFE8E8E4),
    mutedForeground: Color(0xFF5A616B),
    ink: Color(0xFF101418),
    inkForeground: Color(0xFFFFFFFF),
    brand: Color(0xFF4338CA),
    brandSoft: Color(0xFFEEEDFB),
    brandForeground: Color(0xFFFFFFFF),
    gain: Color(0xFF0B7A4B),
    gainSoft: Color(0xFFE7F4ED),
    loss: Color(0xFFC0362C),
    lossSoft: Color(0xFFFBEBE9),
    hold: Color(0xFFA34B07),
    holdSoft: Color(0xFFFBF1E6),
  );

  static const dark = AppPalette(
    background: Color(0xFF0B0D10),
    foreground: Color(0xFFECEDEF),
    surface: Color(0xFF121519),
    surfaceMuted: Color(0xFF1A1E24),
    border: Color(0xFF262B33),
    mutedForeground: Color(0xFF9AA1AC),
    ink: Color(0xFFECEDEF),
    inkForeground: Color(0xFF0B0D10),
    brand: Color(0xFF8F89F3),
    brandSoft: Color(0xFF23224A),
    brandForeground: Color(0xFF0B0D10),
    gain: Color(0xFF3DBE85),
    gainSoft: Color(0xFF10291D),
    loss: Color(0xFFF0705F),
    lossSoft: Color(0xFF34171A),
    hold: Color(0xFFE59A45),
    holdSoft: Color(0xFF33230F),
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
      ink: mix(ink, other.ink),
      inkForeground: mix(inkForeground, other.inkForeground),
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

/// The small upper-case section label ("YOUR STRATEGY", "PREFERENCES").
/// Logo colours (see widgets/brand_mark.dart).
const brandMint = Color(0xFF4EE478);
const brandForest = Color(0xFF114325);

TextStyle labelCaps(AppPalette p) =>
    TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: p.mutedForeground);

/// Prices: large Lato Light with tabular figures.
const priceFeatures = [FontFeature.tabularFigures()];

const fontFamily = 'Lato';

ThemeData buildLightTheme() => _buildTheme(AppPalette.light, Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(AppPalette.dark, Brightness.dark);

ThemeData _buildTheme(AppPalette p, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.brand,
    brightness: brightness,
    primary: p.ink,
    onPrimary: p.inkForeground,
    secondary: p.brand,
    surface: p.surface,
    onSurface: p.foreground,
    onSurfaceVariant: p.mutedForeground,
    outline: p.border,
    outlineVariant: p.border,
    error: p.loss,
  );
  final radius = BorderRadius.circular(12);
  const pill = StadiumBorder();
  const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);
  const buttonText = TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700);
  final base = ThemeData(brightness: brightness, fontFamily: fontFamily).textTheme;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: fontFamily,
    colorScheme: scheme,
    textTheme: base.apply(bodyColor: p.foreground, displayColor: p.foreground),
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
      titleTextStyle: TextStyle(fontFamily: fontFamily, color: p.foreground, fontSize: 20, fontWeight: FontWeight.w700),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.foreground, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      // Main buttons wear the logo: mint tile, forest S.
      style: FilledButton.styleFrom(
        backgroundColor: brandMint,
        foregroundColor: brandForest,
        disabledBackgroundColor: brandMint.withValues(alpha: 0.35),
        disabledForegroundColor: brandForest.withValues(alpha: 0.6),
        overlayColor: brandForest,
        minimumSize: const Size(64, 52),
        padding: buttonPadding,
        shape: pill,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.foreground,
        backgroundColor: p.surfaceMuted,
        minimumSize: const Size(64, 52),
        padding: buttonPadding,
        shape: pill,
        side: BorderSide.none,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.brand,
        textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceMuted,
      selectedColor: p.ink,
      side: BorderSide.none,
      shape: pill,
      showCheckmark: false,
      labelStyle: TextStyle(fontFamily: fontFamily, color: p.foreground, fontSize: 13, fontWeight: FontWeight.w700),
      secondaryLabelStyle: TextStyle(fontFamily: fontFamily, color: p.inkForeground, fontSize: 13, fontWeight: FontWeight.w700),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : p.border),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.foreground,
      unselectedLabelColor: p.mutedForeground,
      indicatorColor: p.foreground,
      dividerColor: p.border,
      labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: fontFamily, color: p.inkForeground, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
