String fmtPct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

String fmtDecimal(double? v, {int digits = 1}) => v == null ? '—' : v.toStringAsFixed(digits);

/// Relative change; null when there is nothing to compare against.
double? pctChange(num current, num? previous) =>
    (previous == null || previous == 0) ? null : (current - previous) / previous;
