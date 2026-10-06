import 'package:flutter/material.dart';

/// Style tokens that Material's ColorScheme has no slot for.
@immutable
class AnalyticsTokens extends ThemeExtension<AnalyticsTokens> {
  const AnalyticsTokens({
    required this.sidebar,
    required this.sidebarFg,
    required this.activeNav,
    required this.activeNavFg,
    required this.good,
    required this.bad,
    required this.grid,
    required this.chart,
    required this.radius,
    required this.displayFont,
  });

  final Color sidebar;
  final Color sidebarFg;
  final Color activeNav;
  final Color activeNavFg;
  final Color good;
  final Color bad;
  final Color grid;
  final List<Color> chart;
  final double radius;
  final String? displayFont;

  /// Tokens of the current theme, or neutral defaults when none are installed.
  static AnalyticsTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AnalyticsTokens>() ?? AnalyticsTokens.fallback(theme);
  }

  factory AnalyticsTokens.fallback(ThemeData theme) {
    final s = theme.colorScheme;
    return AnalyticsTokens(
      sidebar: s.surface,
      sidebarFg: s.onSurface,
      activeNav: s.secondaryContainer,
      activeNavFg: s.onSecondaryContainer,
      good: Colors.green,
      bad: Colors.red,
      grid: s.outlineVariant,
      chart: [s.primary, s.tertiary, s.secondary, s.error],
      radius: 12,
      displayFont: null,
    );
  }

  @override
  AnalyticsTokens copyWith({
    Color? sidebar,
    Color? sidebarFg,
    Color? activeNav,
    Color? activeNavFg,
    Color? good,
    Color? bad,
    Color? grid,
    List<Color>? chart,
    double? radius,
    String? displayFont,
  }) =>
      AnalyticsTokens(
        sidebar: sidebar ?? this.sidebar,
        sidebarFg: sidebarFg ?? this.sidebarFg,
        activeNav: activeNav ?? this.activeNav,
        activeNavFg: activeNavFg ?? this.activeNavFg,
        good: good ?? this.good,
        bad: bad ?? this.bad,
        grid: grid ?? this.grid,
        chart: chart ?? this.chart,
        radius: radius ?? this.radius,
        displayFont: displayFont ?? this.displayFont,
      );

  /// Styles switch instantly; no colour interpolation needed.
  @override
  AnalyticsTokens lerp(ThemeExtension<AnalyticsTokens>? other, double t) =>
      (other is AnalyticsTokens && t >= 0.5) ? other : this;
}
