String fmtPct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

/// Whole numbers without ".0"; fractions keep one decimal.
String fmtCount(num v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

String fmtDecimal(double? v, {int digits = 1}) => v == null ? '—' : v.toStringAsFixed(digits);

/// Relative change; null when there is nothing to compare against.
double? pctChange(num current, num? previous) =>
    (previous == null || previous == 0) ? null : (current - previous) / previous;

/// Compact duration: 20s, 1m 05s, 12h 00m, 1d 1h.
String fmtDuration(double? seconds) {
  if (seconds == null) return '—';
  final s = seconds.round();
  if (s < 60) return '${s}s';
  if (s < 3600) return '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
  if (s < 86400) return '${s ~/ 3600}h ${((s % 3600) ~/ 60).toString().padLeft(2, '0')}m';
  return '${s ~/ 86400}d ${(s % 86400) ~/ 3600}h';
}
