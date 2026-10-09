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

  if (k == 2) {
    // Exact 2-group Mantel-Haenszel log-rank test
    final g1 = activeGroups[0].value;
    final g2 = activeGroups[1].value;

    var o1 = 0.0;
    var e1 = 0.0;
    var v1 = 0.0;

    for (final t in sortedDays) {
      final n1 = g1.where((s) => s.duration >= t).length;
      final n2 = g2.where((s) => s.duration >= t).length;
      final d1 = g1.where((s) => s.duration == t && s.isEvent).length;
      final d2 = g2.where((s) => s.duration == t && s.isEvent).length;

      final n = n1 + n2;
      final d = d1 + d2;

      if (n > 1 && d > 0) {
        o1 += d1;
        final exp1 = n1 * (d / n);
        e1 += exp1;
        v1 += (n1 * n2 * d * (n - d)) / (n * n * (n - 1));
      }
    }

    if (v1 <= 0.0) return null;
    final chiSq = ((o1 - e1) * (o1 - e1)) / v1;
    final pVal = chiSquarePValue(chiSq, 1);
    return LogRankTest(
      chiSquare: chiSq,
      degreesOfFreedom: 1,
      pValue: pVal,
      significant: pVal < 0.05,
    );
  }

  // Multi-group (K > 2) log-rank test
  var totalChiSq = 0.0;
  for (var i = 0; i < k; i++) {
    final gi = activeGroups[i].value;
    final others = [for (var j = 0; j < k; j++) if (j != i) ...activeGroups[j].value];

    var oi = 0.0;
    var ei = 0.0;
    var vi = 0.0;

    for (final t in sortedDays) {
      final ni = gi.where((s) => s.duration >= t).length;
      final no = others.where((s) => s.duration >= t).length;
      final di = gi.where((s) => s.duration == t && s.isEvent).length;
      final do_ = others.where((s) => s.duration == t && s.isEvent).length;

      final n = ni + no;
      final d = di + do_;

      if (n > 1 && d > 0) {
        oi += di;
        ei += ni * (d / n);
        vi += (ni * no * d * (n - d)) / (n * n * (n - 1));
      }
    }

    if (vi > 0.0) {
      totalChiSq += ((oi - ei) * (oi - ei)) / vi;
    }
  }

  // Adjust for (K - 1) degrees of freedom
  final df = k - 1;
  final chiSq = totalChiSq * (df / k);
  final pVal = chiSquarePValue(chiSq, df);

  return LogRankTest(
    chiSquare: chiSq,
    degreesOfFreedom: df,
    pValue: pVal,
    significant: pVal < 0.05,
  );
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
