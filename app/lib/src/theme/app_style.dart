import 'package:flutter/material.dart';

import 'analytics_tokens.dart';

enum AppStyle {
  tremor('Tremor Light', 'Soft grey canvas, white cards, blue charts. Numbers read fastest.'),
  shadcn('shadcn Neutral', 'Black, white and zinc with thin borders. Minimal colour.'),
  midnight('Midnight Game', 'Dark navy like GameAnalytics, cyan and violet charts.'),
  material('Material 3 Soft', 'Tinted surfaces and big rounded cards.');

  const AppStyle(this.label, this.description);
  final String label;
  final String description;
}

AppStyle parseStyle(String? name) =>
    AppStyle.values.firstWhere((s) => s.name == name, orElse: () => AppStyle.tremor);

class StylePalette {
  const StylePalette({
    required this.brightness,
    required this.background,
    required this.sidebar,
    required this.sidebarFg,
    required this.activeNav,
    required this.activeNavFg,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.chart,
    required this.good,
    required this.bad,
    required this.grid,
    required this.radius,
    required this.elevation,
    required this.bodyFont,
    required this.displayFont,
  });

  final Brightness brightness;
  final Color background;
  final Color sidebar;
  final Color sidebarFg;
  final Color activeNav;
  final Color activeNavFg;
  final Color card;
  final Color? border; // null = no border
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final List<Color> chart; // chart[0] == accent
  final Color good;
  final Color bad;
  final Color grid;
  final double radius;
  final double elevation;
  final String bodyFont;
  final String displayFont;
}

/// Values from spec section 6.
const Map<AppStyle, StylePalette> palettes = {
  AppStyle.tremor: StylePalette(
    brightness: Brightness.light,
    background: Color(0xFFF9FAFB),
    sidebar: Color(0xFFFFFFFF),
    sidebarFg: Color(0xFF374151),
    activeNav: Color(0xFFEFF6FF),
    activeNavFg: Color(0xFF1D4ED8),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE5E7EB),
    text: Color(0xFF111827),
    muted: Color(0xFF6B7280),
    accent: Color(0xFF3B82F6),
    onAccent: Color(0xFFFFFFFF),
    chart: [Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFF59E0B)],
    good: Color(0xFF059669),
    bad: Color(0xFFE11D48),
    grid: Color(0xFFF1F5F9),
    radius: 12,
    elevation: 1,
    bodyFont: 'Inter',
    displayFont: 'Inter',
  ),
  AppStyle.shadcn: StylePalette(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    sidebar: Color(0xFFFAFAFA),
    sidebarFg: Color(0xFF3F3F46),
    activeNav: Color(0xFFF4F4F5),
    activeNavFg: Color(0xFF09090B),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE4E4E7),
    text: Color(0xFF09090B),
    muted: Color(0xFF71717A),
    accent: Color(0xFF18181B),
    onAccent: Color(0xFFFAFAFA),
    chart: [Color(0xFF18181B), Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFFEA580C)],
    good: Color(0xFF16A34A),
    bad: Color(0xFFDC2626),
    grid: Color(0xFFF4F4F5),
    radius: 10,
    elevation: 0,
    bodyFont: 'Geist',
    displayFont: 'Geist',
  ),
  AppStyle.midnight: StylePalette(
    brightness: Brightness.dark,
    background: Color(0xFF0B1020),
    sidebar: Color(0xFF0E1427),
    sidebarFg: Color(0xFFAAB4C8),
    activeNav: Color(0xFF16203A),
    activeNavFg: Color(0xFF67E8F9),
    card: Color(0xFF131A2E),
    border: Color(0xFF1F2A44),
    text: Color(0xFFE5E7EB),
    muted: Color(0xFF94A3B8),
    accent: Color(0xFF22D3EE),
    onAccent: Color(0xFF0B1020),
    chart: [Color(0xFF22D3EE), Color(0xFFA78BFA), Color(0xFF34D399), Color(0xFFFBBF24)],
    good: Color(0xFF34D399),
    bad: Color(0xFFFB7185),
    grid: Color(0xFF1A2340),
    radius: 12,
    elevation: 3,
    bodyFont: 'Inter',
    displayFont: 'ChakraPetch',
  ),
  AppStyle.material: StylePalette(
    brightness: Brightness.light,
    background: Color(0xFFF2F4FA),
    sidebar: Color(0xFFE8ECF7),
    sidebarFg: Color(0xFF3A4256),
    activeNav: Color(0xFFD6E0FF),
    activeNavFg: Color(0xFF1C3FAA),
    card: Color(0xFFFFFFFF),
    border: null,
    text: Color(0xFF1A1F2C),
    muted: Color(0xFF5B6476),
    accent: Color(0xFF3559E0),
    onAccent: Color(0xFFFFFFFF),
    chart: [Color(0xFF3559E0), Color(0xFF0E9F8C), Color(0xFFC2558E), Color(0xFFE08A1E)],
    good: Color(0xFF0E8A5F),
    bad: Color(0xFFC2384F),
    grid: Color(0xFFEEF1F8),
    radius: 20,
    elevation: 1,
    bodyFont: 'Manrope',
    displayFont: 'Manrope',
  ),
};

ThemeData buildTheme(AppStyle style) {
  final p = palettes[style]!;
  final line = p.border ?? p.grid;
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: p.brightness).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.card,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    outline: line,
    outlineVariant: line,
    error: p.bad,
    surfaceContainerLowest: p.card,
    surfaceContainerLow: p.background,
    surfaceContainer: p.background,
    surfaceContainerHigh: p.card,
    surfaceContainerHighest: p.grid,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    fontFamily: p.bodyFont,
  );
  TextStyle? display(TextStyle? s) => s?.copyWith(fontFamily: p.displayFont, fontWeight: FontWeight.w700);
  final radius = BorderRadius.circular(p.radius);
  final controlRadius = BorderRadius.circular(p.radius > 6 ? p.radius - 4 : p.radius);

  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: line,
    textTheme: base.textTheme.copyWith(
      headlineMedium: display(base.textTheme.headlineMedium),
      headlineSmall: display(base.textTheme.headlineSmall),
      titleLarge: display(base.textTheme.titleLarge),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: base.textTheme.labelMedium?.copyWith(color: p.muted),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: p.elevation,
      shadowColor: Colors.black.withValues(alpha: p.brightness == Brightness.dark ? 0.5 : 0.12),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: p.border == null ? BorderSide.none : BorderSide(color: p.border!),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: controlRadius)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: controlRadius)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: controlRadius)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    extensions: [
      AnalyticsTokens(
        sidebar: p.sidebar,
        sidebarFg: p.sidebarFg,
        activeNav: p.activeNav,
        activeNavFg: p.activeNavFg,
        good: p.good,
        bad: p.bad,
        grid: p.grid,
        chart: p.chart,
        radius: p.radius,
        displayFont: p.displayFont,
      ),
    ],
  );
}
