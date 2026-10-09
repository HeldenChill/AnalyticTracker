import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';

typedef SubjectDuration = ({int duration, bool isEvent});

/// Computes Kaplan-Meier survival curve with Greenwood 95% CI (spec §6c).
/// Starts with day 0 at survival 1.0. Days are sorted 0..maxDays.
List<SurvivalPoint> computeKaplanMeier(List<SubjectDuration> subjects) {
  if (subjects.isEmpty) return const [];

  final maxDay = subjects.map((s) => s.duration).fold(0, max);
  final eventsByDay = <int, int>{};
  final censoredByDay = <int, int>{};

  for (final s in subjects) {
    if (s.isEvent) {
      eventsByDay[s.duration] = (eventsByDay[s.duration] ?? 0) + 1;
    } else {
      censoredByDay[s.duration] = (censoredByDay[s.duration] ?? 0) + 1;
    }
  }

  final points = <SurvivalPoint>[];
  var currentSurvival = 1.0;
  var sumVarianceTerms = 0.0;
  var atRisk = subjects.length;

  // Day 0: Baseline entry
  points.add(SurvivalPoint(
    day: 0,
    survival: 1.0,
    ciLower: 1.0,
    ciUpper: 1.0,
    atRisk: atRisk,
    events: 0,
    censored: 0,
  ));

  for (var day = 1; day <= maxDay; day++) {
    final d = eventsByDay[day] ?? 0;
    final c = censoredByDay[day] ?? 0;

    if (atRisk <= 0) {
      points.add(SurvivalPoint(
        day: day,
        survival: currentSurvival,
        ciLower: points.last.ciLower,
        ciUpper: points.last.ciUpper,
        atRisk: 0,
        events: 0,
        censored: 0,
      ));
      continue;
    }

    if (d > 0) {
      currentSurvival *= (1.0 - d / atRisk);
      if (atRisk - d > 0) {
        sumVarianceTerms += d / (atRisk * (atRisk - d));
      }
    }

    final se = currentSurvival * sqrt(sumVarianceTerms);
    final ciLower = (currentSurvival - 1.96 * se).clamp(0.0, 1.0);
    final ciUpper = (currentSurvival + 1.96 * se).clamp(0.0, 1.0);

    points.add(SurvivalPoint(
      day: day,
      survival: currentSurvival,
      ciLower: ciLower,
      ciUpper: ciUpper,
      atRisk: atRisk,
      events: d,
      censored: c,
    ));

    atRisk -= (d + c);
  }

  return points;
}

/// Finds median survival days (first day where survival drops <= 0.5).
double? computeMedianSurvivalDays(List<SurvivalPoint> points) {
  for (final p in points) {
    if (p.survival <= 0.5) return p.day.toDouble();
  }
  return null;
}

/// Computes log-rank test across K groups (spec §6c).
/// Uses full (K-1) x (K-1) variance-covariance matrix formulation.
LogRankTest? computeLogRank(Map<String, List<SubjectDuration>> groups) {
  final activeGroups = groups.entries.where((e) => e.value.isNotEmpty).toList();
  if (activeGroups.length < 2) return null;

  // Collect all distinct event times across all groups
  final allEventDays = <int>{};
  for (final g in activeGroups) {
    for (final s in g.value) {
      if (s.isEvent && s.duration > 0) allEventDays.add(s.duration);
    }
  }
  if (allEventDays.isEmpty) return null;

  final sortedDays = allEventDays.toList()..sort();
  final k = activeGroups.length;
  final m = k - 1; // degrees of freedom

  // v = O_i - E_i for first (K-1) groups
  final v = List.filled(m, 0.0);
  // V = covariance matrix of size (K-1) x (K-1)
  final cov = List.generate(m, (_) => List.filled(m, 0.0));

  for (final t in sortedDays) {
    final risks = List.generate(k, (i) => activeGroups[i].value.where((s) => s.duration >= t).length);
    final events = List.generate(k, (i) => activeGroups[i].value.where((s) => s.duration == t && s.isEvent).length);

    final totalRisk = risks.fold(0, (a, b) => a + b);
    final totalEvents = events.fold(0, (a, b) => a + b);

    if (totalRisk > 1 && totalEvents > 0) {
      final n = totalRisk.toDouble();
      final d = totalEvents.toDouble();
      final factor = (d * (n - d)) / (n * n * (n - 1));

      for (var i = 0; i < m; i++) {
        final ni = risks[i].toDouble();
        final di = events[i].toDouble();
        final ei = ni * (d / n);
        v[i] += di - ei;

        for (var j = 0; j < m; j++) {
          final nj = risks[j].toDouble();
          if (i == j) {
            cov[i][j] += (ni * (n - ni)) * factor;
          } else {
            cov[i][j] -= (ni * nj) * factor;
          }
        }
      }
    }
  }

  // Solve V * x = v for x, then chiSq = v^T * x
  final x = _solveLinearSystem(cov, v);
  if (x == null) return null;

  var chiSq = 0.0;
  for (var i = 0; i < m; i++) {
    chiSq += v[i] * x[i];
  }
  if (chiSq < 0.0) chiSq = 0.0;

  final pVal = chiSquarePValue(chiSq, m);

  return LogRankTest(
    chiSquare: chiSq,
    degreesOfFreedom: m,
    pValue: pVal,
    significant: pVal < 0.05,
  );
}

/// Solves A * x = b using Gaussian elimination with partial pivoting.
List<double>? _solveLinearSystem(List<List<double>> a, List<double> b) {
  final n = b.length;
  final mat = List.generate(n, (i) => List.generate(n + 1, (j) => j < n ? a[i][j] : b[i]));

  for (var i = 0; i < n; i++) {
    var maxRow = i;
    var maxVal = mat[i][i].abs();
    for (var r = i + 1; r < n; r++) {
      if (mat[r][i].abs() > maxVal) {
        maxVal = mat[r][i].abs();
        maxRow = r;
      }
    }
    if (maxVal < 1e-12) return null; // Singular matrix

    if (maxRow != i) {
      final tmp = mat[i];
      mat[i] = mat[maxRow];
      mat[maxRow] = tmp;
    }

    final pivot = mat[i][i];
    for (var j = i; j <= n; j++) {
      mat[i][j] /= pivot;
    }
    for (var r = 0; r < n; r++) {
      if (r != i) {
        final factor = mat[r][i];
        if (factor.abs() > 1e-15) {
          for (var j = i; j <= n; j++) {
            mat[r][j] -= factor * mat[i][j];
          }
        }
      }
    }
  }

  return List.generate(n, (i) => mat[i][n]);
}

/// Chi-square survival function P(X >= chiSquare, df) (upper tail p-value).
double chiSquarePValue(double chiSquare, int df) {
  if (chiSquare <= 0.0 || df <= 0) return 1.0;

  if (df == 1) {
    final z = sqrt(chiSquare / 2.0);
    return _erfc(z);
  }

  return _gammaQ(df / 2.0, chiSquare / 2.0);
}

double _erfc(double x) {
  final t = 1.0 / (1.0 + 0.5 * x);
  final tau = t * exp(-x * x - 1.26551223 +
      t * (1.00002368 +
      t * (0.37409196 +
      t * (0.09678418 +
      t * (-0.18628806 +
      t * (0.27886807 +
      t * (-1.13520398 +
      t * (1.48851587 +
      t * (-0.82215223 +
      t * 0.17087277)))))))));
  return tau.clamp(0.0, 1.0);
}

double _gammaQ(double a, double x) {
  if (x < a + 1.0) {
    var sum = 1.0 / a;
    var term = 1.0 / a;
    for (var n = 1; n < 100; n++) {
      term *= x / (a + n);
      sum += term;
      if (term.abs() < sum.abs() * 1e-12) break;
    }
    final gln = _logGamma(a);
    final p = sum * exp(-x + a * log(x) - gln);
    return (1.0 - p).clamp(0.0, 1.0);
  } else {
    var b = x + 1.0 - a;
    var c = 1.0 / 1e-30;
    var d = 1.0 / b;
    var h = d;
    for (var i = 1; i < 100; i++) {
      final an = -i * (i - a);
      b += 2.0;
      d = an * d + b;
      if (d.abs() < 1e-30) d = 1e-30;
      c = b + an / c;
      if (c.abs() < 1e-30) c = 1e-30;
      d = 1.0 / d;
      final del = d * c;
      h *= del;
      if ((del - 1.0).abs() < 1e-12) break;
    }
    final gln = _logGamma(a);
    final q = exp(-x + a * log(x) - gln) * h;
    return q.clamp(0.0, 1.0);
  }
}

double _logGamma(double x) {
  final p = [
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.138571095836524,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  var y = x;
  var tmp = x + 7.5;
  tmp = (x - 0.5) * log(tmp) - tmp;
  var ser = 0.99999999999980993;
  for (var i = 0; i < p.length; i++) {
    ser += p[i] / ++y;
  }
  return tmp + log(sqrt(2 * pi) * ser);
}
