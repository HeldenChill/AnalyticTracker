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

  @override
  AnalyticsTokens lerp(ThemeExtension<AnalyticsTokens>? other, double t) {
    if (other is! AnalyticsTokens) return this;
    if (t == 0) return this;
    if (t == 1) return other;

    final thisChart = chart.isEmpty ? [good] : chart;
    final otherChart = other.chart.isEmpty ? [other.good] : other.chart;
    final targetLen = t <= 0.5 ? thisChart.length : otherChart.length;
    final lerpedChart = <Color>[
      for (var i = 0; i < targetLen; i++)
        Color.lerp(
          thisChart[i < thisChart.length ? i : thisChart.length - 1],
          otherChart[i < otherChart.length ? i : otherChart.length - 1],
          t,
        ) ??
            (t < 0.5
                ? thisChart[i < thisChart.length ? i : thisChart.length - 1]
                : otherChart[i < otherChart.length ? i : otherChart.length - 1]),
    ];

    return AnalyticsTokens(
      sidebar: Color.lerp(sidebar, other.sidebar, t) ?? (t < 0.5 ? sidebar : other.sidebar),
      sidebarFg: Color.lerp(sidebarFg, other.sidebarFg, t) ?? (t < 0.5 ? sidebarFg : other.sidebarFg),
      activeNav: Color.lerp(activeNav, other.activeNav, t) ?? (t < 0.5 ? activeNav : other.activeNav),
      activeNavFg: Color.lerp(activeNavFg, other.activeNavFg, t) ?? (t < 0.5 ? activeNavFg : other.activeNavFg),
      good: Color.lerp(good, other.good, t) ?? (t < 0.5 ? good : other.good),
      bad: Color.lerp(bad, other.bad, t) ?? (t < 0.5 ? bad : other.bad),
      grid: Color.lerp(grid, other.grid, t) ?? (t < 0.5 ? grid : other.grid),
      chart: lerpedChart,
      radius: radius + (other.radius - radius) * t,
      displayFont: t < 0.5 ? displayFont : other.displayFont,
    );
  }
}
