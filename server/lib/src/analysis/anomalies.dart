import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';

/// Computes the median of a non-empty numeric list.
double computeMedian(List<double> values) {
  if (values.isEmpty) return 0.0;
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[mid];
  }
  return (sorted[mid - 1] + sorted[mid]) / 2.0;
}

/// Computes the Median Absolute Deviation (MAD) against [median].
double computeMad(List<double> values, double median) {
  if (values.isEmpty) return 0.0;
  final diffs = [for (final v in values) (v - median).abs()];
  return computeMedian(diffs);
}

/// Computes robust z-score = (x - median) / (1.4826 * MAD).
/// When MAD == 0, flags only when x differs from median by >= 50%.
double computeRobustZ(double x, double median, double mad) {
  if (mad > 0) {
    return (x - median) / (1.4826 * mad);
  }
  // MAD == 0: all baseline values are identical or mostly identical
  final denom = median.abs() == 0 ? 1.0 : median.abs();
  final relDiff = (x - median).abs() / denom;
  if (relDiff >= 0.5) {
    // Escalate to an alert magnitude >= 3.0 proportional to relative difference
    final sign = x >= median ? 1.0 : -1.0;
    return sign * 3.0 * (relDiff / 0.5);
  }
  return 0.0;
}

/// Detects anomalies across daily metric series using rolling 14-day history (spec §7).
List<AnomalyAlert> detectAnomalies(
  Map<String, List<AnomalyAlertPoint>> seriesData, {
  int minBaselineDays = 7,
  int maxBaselineDays = 14,
  double thresholdZ = 3.0,
  int limit = 30,
}) {
  final alerts = <AnomalyAlert>[];

  for (final entry in seriesData.entries) {
    final series = entry.key;
    final points = List<AnomalyAlertPoint>.from(entry.value)
      ..sort((a, b) => a.day.compareTo(b.day));

    for (var i = 0; i < points.length; i++) {
      final target = points[i];
      final startIdx = max(0, i - maxBaselineDays);
      final baselinePoints = points.sublist(startIdx, i);

      if (baselinePoints.length < minBaselineDays) continue;

      final baselineValues = [for (final p in baselinePoints) p.value];
      final median = computeMedian(baselineValues);
      final mad = computeMad(baselineValues, median);
      final z = computeRobustZ(target.value, median, mad);

      if (z.abs() >= thresholdZ) {
        final valStr = target.value == target.value.roundToDouble()
            ? target.value.toInt().toString()
            : target.value.toStringAsFixed(1);
        final medStr = median == median.roundToDouble()
            ? median.toInt().toString()
            : median.toStringAsFixed(1);
        final zStr = z.toStringAsFixed(1);

        final message = '$series: $valStr on ${target.day}, usual ~$medStr, z = $zStr';

        // Full history window including baseline plus evaluated point
        final historyWindow = points.sublist(startIdx, i + 1);

        alerts.add(AnomalyAlert(
          series: series,
          day: target.day,
          value: target.value,
          median: double.parse(median.toStringAsFixed(2)),
          mad: double.parse(mad.toStringAsFixed(2)),
          z: double.parse(z.toStringAsFixed(2)),
          message: message,
          history: historyWindow,
        ));
      }
    }
  }

  // Sort by |z| descending, latest first on ties
  alerts.sort((a, b) {
    final cmpZ = b.z.abs().compareTo(a.z.abs());
    if (cmpZ != 0) return cmpZ;
    return b.day.compareTo(a.day);
  });

  return alerts.take(limit).toList();
}
