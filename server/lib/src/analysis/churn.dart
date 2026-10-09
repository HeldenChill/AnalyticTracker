import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';

import 'features.dart';
import 'tree.dart';

/// Inactivity threshold for churn in days (spec §5).
const churnInactivityDays = 7;

/// Cohen's d with pooled standard deviation (spec §5).
double cohensD(List<double> churned, List<double> stayed) {
  final nc = churned.length;
  final ns = stayed.length;
  if (nc + ns <= 2) return 0.0;

  final mc = churned.fold(0.0, (a, b) => a + b) / nc;
  final ms = stayed.fold(0.0, (a, b) => a + b) / ns;

  var sqC = 0.0;
  for (final v in churned) {
    sqC += (v - mc) * (v - mc);
  }
  var sqS = 0.0;
  for (final v in stayed) {
    sqS += (v - ms) * (v - ms);
  }

  final varC = nc > 1 ? sqC / (nc - 1) : 0.0;
  final varS = ns > 1 ? sqS / (ns - 1) : 0.0;

  final pooledSd = sqrt(((nc - 1) * varC + (ns - 1) * varS) / (nc + ns - 2));
  if (pooledSd < 1e-12) return 0.0;

  return (mc - ms) / pooledSd;
}

ChurnResult analyzeChurn(
  PlayerFeatures pf,
  List<bool> churnLabels,
  int excludedCount,
  int totalPlayers,
) {
  final observable = pf.players.length;
  if (observable == 0) {
    return ChurnResult(
      players: totalPlayers,
      observable: 0,
      churned: 0,
      stayed: 0,
      excluded: excludedCount,
      churnRate: 0.0,
      drivers: const [],
      rules: const [],
      reason: 'not_observable',
    );
  }

  final churnedIndices = <int>[];
  final stayedIndices = <int>[];
  for (var i = 0; i < observable; i++) {
    if (churnLabels[i]) {
      churnedIndices.add(i);
    } else {
      stayedIndices.add(i);
    }
  }

  final nc = churnedIndices.length;
  final ns = stayedIndices.length;
  final churnRate = nc / observable;

  final drivers = <ChurnDriver>[];
  for (var col = 0; col < pf.keys.length; col++) {
    final feature = pf.keys[col];
    final cVals = [for (final i in churnedIndices) pf.rows[i][col]];
    final sVals = [for (final i in stayedIndices) pf.rows[i][col]];

    final mc = cVals.isEmpty ? 0.0 : cVals.fold(0.0, (a, b) => a + b) / (nc == 0 ? 1 : nc);
    final ms = sVals.isEmpty ? 0.0 : sVals.fold(0.0, (a, b) => a + b) / (ns == 0 ? 1 : ns);

    final ratio = ms > 0 ? (mc / ms) : null;
    final d = cohensD(cVals, sVals);
    final cRate = cVals.isEmpty ? 0.0 : cVals.where((v) => v > 0).length / (nc == 0 ? 1 : nc);
    final sRate = sVals.isEmpty ? 0.0 : sVals.where((v) => v > 0).length / (ns == 0 ? 1 : ns);

    drivers.add(ChurnDriver(
      feature: feature,
      meanChurned: mc,
      meanStayed: ms,
      ratio: ratio,
      cohensD: d,
      churnedRate: cRate,
      stayedRate: sRate,
      smallSample: nc < 10 || ns < 10,
    ));
  }

  // Ranked by |cohensD| descending
  drivers.sort((a, b) => b.cohensD.abs().compareTo(a.cohensD.abs()));

  final rulesFit = fitChurnTree(pf.rows, churnLabels, pf.keys);
  final reason = observable < 20 ? 'too_few_players' : null;

  return ChurnResult(
    players: totalPlayers,
    observable: observable,
    churned: nc,
    stayed: ns,
    excluded: excludedCount,
    churnRate: churnRate,
    drivers: drivers,
    rules: observable < 20 ? const [] : rulesFit.rules,
    reason: reason,
  );
}
