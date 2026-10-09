import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';

// ponytail: PVM-specific blocklist identical to features.dart
const blocklist = {
  'screen_view',
  'user_engagement',
  'session_start',
  'first_open',
  'app_remove',
  'app_clear_data',
  'firebase_campaign',
};

final _levelEventRe = RegExp(r'^level_(\d+)_(start|complete|fail)$');

class PlayerRawEvent {
  const PlayerRawEvent(this.uid, this.name, this.tsMicros);
  final String uid;
  final String name;
  final int tsMicros;
}

/// Fits empirical Bayes Beta prior (alpha, beta) using method of moments (spec §6a).
(double, double) fitBetaPrior(List<double> winRates) {
  if (winRates.length < 3) return (1.0, 1.0);

  final n = winRates.length;
  final m = winRates.fold(0.0, (a, b) => a + b) / n;
  if (m <= 0.0 || m >= 1.0 || m.isNaN) return (1.0, 1.0);

  var sq = 0.0;
  for (final r in winRates) {
    sq += (r - m) * (r - m);
  }
  final v = sq / (n - 1);
  if (v <= 0.0 || v >= m * (1.0 - m) || v.isNaN) return (1.0, 1.0);

  final mult = (m * (1.0 - m) / v) - 1.0;
  if (mult <= 0.0 || mult.isNaN || mult.isInfinite) return (1.0, 1.0);

  final alpha = m * mult;
  final beta = (1.0 - m) * mult;
  if (alpha <= 0.0 || beta <= 0.0 || alpha.isNaN || beta.isNaN) return (1.0, 1.0);

  return (alpha, beta);
}

LevelResult analyzeLevels({
  required int totalPlayers,
  required List<String> players,
  required Map<String, List<PlayerRawEvent>> playerEvents,
  required Set<String> activeAtEnd,
  required Set<String> observable,
  required Set<String> churned,
}) {
  if (totalPlayers < 20) {
    return LevelResult(
      players: totalPlayers,
      observable: observable.length,
      levels: const [],
      exitEvents: const [],
      transitions: const [],
      medianHazard: 0.0,
      reason: 'too_few_players',
    );
  }

  // 1. Group level stats
  final attemptsMap = <int, int>{};
  final completesMap = <int, int>{};
  final failsMap = <int, int>{};
  final reachedPlayers = <int, Set<String>>{};
  final playerMaxLevel = <String, int>{};

  for (final p in players) {
    final events = playerEvents[p] ?? const [];
    var maxLvl = 0;
    for (final e in events) {
      final m = _levelEventRe.firstMatch(e.name);
      if (m != null) {
        final lvl = int.parse(m.group(1)!);
        final action = m.group(2)!;
        maxLvl = max(maxLvl, lvl);
        reachedPlayers.putIfAbsent(lvl, () => {}).add(p);
        if (action == 'complete') {
          completesMap[lvl] = (completesMap[lvl] ?? 0) + 1;
          attemptsMap[lvl] = (attemptsMap[lvl] ?? 0) + 1;
        } else if (action == 'fail') {
          failsMap[lvl] = (failsMap[lvl] ?? 0) + 1;
          attemptsMap[lvl] = (attemptsMap[lvl] ?? 0) + 1;
        }
      }
    }
    if (maxLvl > 0) {
      playerMaxLevel[p] = maxLvl;
    }
  }

  final allLevels = reachedPlayers.keys.toList()..sort();
  if (allLevels.isEmpty) {
    return LevelResult(
      players: totalPlayers,
      observable: observable.length,
      levels: const [],
      exitEvents: const [],
      transitions: const [],
      medianHazard: 0.0,
      reason: 'no_level_events',
    );
  }

  // Calculate raw win rates for empirical Bayes (levels with >= 5 attempts)
  final ratesForPrior = <double>[];
  for (final lvl in allLevels) {
    final att = attemptsMap[lvl] ?? 0;
    if (att >= 5) {
      final comp = completesMap[lvl] ?? 0;
      ratesForPrior.add(comp / att);
    }
  }
  final (alpha, beta) = fitBetaPrior(ratesForPrior);

  // Reached & Stopped per level
  final stoppedMap = <int, int>{};
  for (final entry in playerMaxLevel.entries) {
    final uid = entry.key;
    final lvl = entry.value;
    if (!activeAtEnd.contains(uid)) {
      stoppedMap[lvl] = (stoppedMap[lvl] ?? 0) + 1;
    }
  }

  // Compute hazards and median hazard over levels with reached >= 10
  final hazardsForMedian = <double>[];
  final levelRawStats = <int, ({int reached, int stopped, double hazard, int attempts, int completes, int fails, double rawWin, double smoothedWin})>{};

  for (final lvl in allLevels) {
    final reached = reachedPlayers[lvl]?.length ?? 0;
    final stopped = stoppedMap[lvl] ?? 0;
    final hazard = reached > 0 ? (stopped / reached) : 0.0;
    final attempts = attemptsMap[lvl] ?? 0;
    final completes = completesMap[lvl] ?? 0;
    final fails = failsMap[lvl] ?? 0;
    final rawWin = attempts > 0 ? (completes / attempts) : 0.0;
    final smoothedWin = (completes + alpha) / (attempts + alpha + beta);

    levelRawStats[lvl] = (
      reached: reached,
      stopped: stopped,
      hazard: hazard,
      attempts: attempts,
      completes: completes,
      fails: fails,
      rawWin: rawWin,
      smoothedWin: smoothedWin,
    );

    if (reached >= 10) {
      hazardsForMedian.add(hazard);
    }
  }

  double medianHazard = 0.0;
  if (hazardsForMedian.isNotEmpty) {
    hazardsForMedian.sort();
    final mid = hazardsForMedian.length ~/ 2;
    if (hazardsForMedian.length.isOdd) {
      medianHazard = hazardsForMedian[mid];
    } else {
      medianHazard = (hazardsForMedian[mid - 1] + hazardsForMedian[mid]) / 2.0;
    }
  }

  final levelStatsList = <LevelStats>[];
  for (final lvl in allLevels) {
    final s = levelRawStats[lvl]!;
    final isWall = s.reached >= 10 && s.hazard > 2.0 * medianHazard;
    levelStatsList.add(LevelStats(
      level: lvl,
      attempts: s.attempts,
      completes: s.completes,
      fails: s.fails,
      rawWinRate: s.rawWin,
      smoothedWinRate: s.smoothedWin,
      reached: s.reached,
      stopped: s.stopped,
      hazard: s.hazard,
      wall: isWall,
    ));
  }

  // 2. Exit events (§6b)
  final churnedExitCounts = <String, int>{};
  final stayedExitCounts = <String, int>{};
  var churnedWithExit = 0;
  var stayedWithExit = 0;

  for (final p in observable) {
    final events = playerEvents[p] ?? const [];
    final nonBlocked = events.where((e) => !blocklist.contains(e.name)).toList();
    if (nonBlocked.isNotEmpty) {
      final exitEvent = nonBlocked.last.name;
      if (churned.contains(p)) {
        churnedExitCounts[exitEvent] = (churnedExitCounts[exitEvent] ?? 0) + 1;
        churnedWithExit++;
      } else {
        stayedExitCounts[exitEvent] = (stayedExitCounts[exitEvent] ?? 0) + 1;
        stayedWithExit++;
      }
    }
  }

  final exitEvents = <ExitEvent>[];
  for (final entry in churnedExitCounts.entries) {
    final evName = entry.key;
    final cCount = entry.value;
    if (cCount >= 5) {
      final sCount = stayedExitCounts[evName] ?? 0;
      final cShare = churnedWithExit > 0 ? cCount / churnedWithExit : 0.0;
      final sShare = stayedWithExit > 0 ? sCount / stayedWithExit : 0.0;
      final lift = sShare > 0.0 ? (cShare / sShare) : null;
      exitEvents.add(ExitEvent(
        eventName: evName,
        churnedCount: cCount,
        stayedCount: sCount,
        churnedShare: cShare,
        stayedShare: sShare,
        lift: lift,
      ));
    }
  }
  exitEvents.sort((a, b) {
    if (a.lift != null && b.lift != null) {
      return b.lift!.compareTo(a.lift!);
    }
    if (a.lift != null) return -1;
    if (b.lift != null) return 1;
    return b.churnedCount.compareTo(a.churnedCount);
  });

  // 3. Markov transitions (§6b)
  // Find top 15 event names after blocklist
  final totalCounts = <String, int>{};
  for (final p in players) {
    for (final e in playerEvents[p] ?? const []) {
      if (!blocklist.contains(e.name)) {
        totalCounts[e.name] = (totalCounts[e.name] ?? 0) + 1;
      }
    }
  }
  final top15Events = (totalCounts.keys.toList()
        ..sort((a, b) => totalCounts[b]!.compareTo(totalCounts[a]!)))
      .take(15)
      .toSet();

  final transitionCounts = <String, Map<String, int>>{};
  for (final p in players) {
    final evs = (playerEvents[p] ?? const []).where((e) => !blocklist.contains(e.name)).toList();
    for (var i = 0; i < evs.length - 1; i++) {
      final from = evs[i].name;
      final to = evs[i + 1].name;
      transitionCounts.putIfAbsent(from, () => {})[to] =
          (transitionCounts[from]![to] ?? 0) + 1;
    }
    if (churned.contains(p) && evs.isNotEmpty) {
      final lastEv = evs.last.name;
      transitionCounts.putIfAbsent(lastEv, () => {})['quit'] =
          (transitionCounts[lastEv]!['quit'] ?? 0) + 1;
    }
  }

  final transitions = <EventTransition>[];
  for (final from in top15Events) {
    final nextMap = transitionCounts[from] ?? const {};
    final totalFrom = nextMap.values.fold(0, (a, b) => a + b);
    if (totalFrom == 0) continue;

    final candidates = <EventTransition>[];
    for (final entry in nextMap.entries) {
      if (entry.value >= 5) {
        candidates.add(EventTransition(
          fromEvent: from,
          toEvent: entry.key,
          count: entry.value,
          probability: entry.value / totalFrom,
        ));
      }
    }
    candidates.sort((a, b) => b.probability.compareTo(a.probability));
    transitions.addAll(candidates.take(3));
  }

  return LevelResult(
    players: totalPlayers,
    observable: observable.length,
    levels: levelStatsList,
    exitEvents: exitEvents,
    transitions: transitions,
    medianHazard: medianHazard,
    reason: null,
  );
}
