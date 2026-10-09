import 'dart:math';

/// Percentile bootstrap confidence interval for difference (target - baseline) (spec §6d).
/// Deterministic with [seed] = 42.
({double difference, double ciLower, double ciUpper, bool significant}) bootstrapCi(
  List<double> target,
  List<double> baseline,
  double Function(List<double>) stat, {
  int resamples = 1000,
  int seed = 42,
}) {
  final targetStat = stat(target);
  final baselineStat = stat(baseline);
  final diff = targetStat - baselineStat;

  if (target.isEmpty || baseline.isEmpty || resamples < 10) {
    return (
      difference: diff,
      ciLower: diff,
      ciUpper: diff,
      significant: false,
    );
  }

  final rng = Random(seed);
  final bootDiffs = <double>[];

  final nT = target.length;
  final nB = baseline.length;

  for (var b = 0; b < resamples; b++) {
    final resampleT = [for (var i = 0; i < nT; i++) target[rng.nextInt(nT)]];
    final resampleB = [for (var i = 0; i < nB; i++) baseline[rng.nextInt(nB)]];
    bootDiffs.add(stat(resampleT) - stat(resampleB));
  }

  bootDiffs.sort();

  final lowerIndex = (0.025 * resamples).floor().clamp(0, resamples - 1);
  final upperIndex = (0.975 * resamples).floor().clamp(0, resamples - 1);

  final ciLower = bootDiffs[lowerIndex];
  final ciUpper = bootDiffs[upperIndex];

  // Significant if CI excludes 0 (both positive or both negative)
  final significant = (ciLower > 0.0 && ciUpper > 0.0) || (ciLower < 0.0 && ciUpper < 0.0);

  return (
    difference: diff,
    ciLower: ciLower,
    ciUpper: ciUpper,
    significant: significant,
  );
}
