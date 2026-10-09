import 'package:analytic_shared/analytic_shared.dart';

import 'bootstrap.dart';
import 'levels.dart';
import 'survival.dart';

class PlayerVersionData {
  const PlayerVersionData({
    required this.uid,
    required this.version,
    required this.sessions,
    required this.playtimeMin,
    required this.survivedD1,
    this.d1Observable = true,
    required this.levelAttempts,
  });

  final String uid;
  final String version;
  final int sessions;
  final double playtimeMin;
  final bool survivedD1;
  final bool d1Observable;
  final Map<int, ({int completes, int fails})> levelAttempts;
}

/// Groups survival curves by dimension [by], merging groups < 10 into 'Other' (spec §6c).
SurvivalResult analyzeSurvivalData({
  required int totalPlayers,
  required Map<String, String> playerGroups,
  required Map<String, SubjectDuration> playerDurations,
  required String by,
}) {
  if (totalPlayers < 20) {
    return SurvivalResult(
      players: totalPlayers,
      by: by,
      curves: const [],
      logRank: null,
      reason: 'too_few_players',
    );
  }

  // Count players per raw group
  final rawCounts = <String, int>{};
  for (final p in playerDurations.keys) {
    final g = playerGroups[p] ?? 'Unknown';
    rawCounts[g] = (rawCounts[g] ?? 0) + 1;
  }

  // Group players; merge < 10 players into 'Other'
  final groupedSubjects = <String, List<SubjectDuration>>{};
  for (final entry in playerDurations.entries) {
    final p = entry.key;
    final dur = entry.value;
    final rawG = playerGroups[p] ?? 'Unknown';
    final groupName = (rawCounts[rawG] ?? 0) >= 10 ? rawG : 'Other';
    groupedSubjects.putIfAbsent(groupName, () => []).add(dur);
  }

  // Generate curves per group
  final curves = <SurvivalCurve>[];
  for (final entry in groupedSubjects.entries) {
    final name = entry.key;
    final list = entry.value;
    final pts = computeKaplanMeier(list);
    final events = list.where((s) => s.isEvent).length;
    final censored = list.length - events;
    final median = computeMedianSurvivalDays(pts);

    curves.add(SurvivalCurve(
      group: name,
      players: list.length,
      events: events,
      censored: censored,
      medianDays: median,
      points: pts,
    ));
  }

  // Sort curves by player count descending, 'Other' last
  curves.sort((a, b) {
    if (a.group == 'Other') return 1;
    if (b.group == 'Other') return -1;
    return b.players.compareTo(a.players);
  });

  final logRank = computeLogRank(groupedSubjects);

  return SurvivalResult(
    players: totalPlayers,
    by: by,
    curves: curves,
    logRank: logRank,
    reason: null,
  );
}

/// Compares target version with previous chronological version having >= 20 players (spec §6d).
VersionImpactResult analyzeVersionImpactData({
  required List<String> chronologicalVersions,
  required Map<String, List<PlayerVersionData>> playersByVersion,
  String? targetVersion,
}) {
  final eligibleVersions = [
    for (final v in chronologicalVersions)
      if ((playersByVersion[v]?.length ?? 0) >= 20) v,
  ];

  if (eligibleVersions.length < 2) {
    return VersionImpactResult(
      targetVersion: targetVersion ??
          (eligibleVersions.isEmpty ? '' : eligibleVersions.last),
      targetPlayers: targetVersion != null
          ? (playersByVersion[targetVersion]?.length ?? 0)
          : 0,
      baselineVersion: '',
      baselinePlayers: 0,
      metrics: const [],
      availableVersions: eligibleVersions,
      reason: 'too_few_players',
    );
  }

  // Resolve target version (default = newest eligible)
  final resolvedTarget =
      (targetVersion != null && eligibleVersions.contains(targetVersion))
          ? targetVersion
          : eligibleVersions.last;

  final targetIndex = eligibleVersions.indexOf(resolvedTarget);
  if (targetIndex <= 0) {
    return VersionImpactResult(
      targetVersion: resolvedTarget,
      targetPlayers: playersByVersion[resolvedTarget]!.length,
      baselineVersion: '',
      baselinePlayers: 0,
      metrics: const [],
      availableVersions: eligibleVersions,
      reason: 'no_previous_version',
    );
  }

  final baselineVersion = eligibleVersions[targetIndex - 1];
  final targetList = playersByVersion[resolvedTarget]!;
  final baselineList = playersByVersion[baselineVersion]!;

  double mean(List<double> xs) =>
      xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;

  final metrics = <VersionMetricImpact>[];

  // 1. D1 Survival
  final d1Target = [
    for (final p in targetList)
      if (p.d1Observable) p.survivedD1 ? 1.0 : 0.0
  ];
  final d1Baseline = [
    for (final p in baselineList)
      if (p.d1Observable) p.survivedD1 ? 1.0 : 0.0
  ];
  if (d1Target.isNotEmpty && d1Baseline.isNotEmpty) {
    final d1Boot = bootstrapCi(d1Target, d1Baseline, mean);
    metrics.add(VersionMetricImpact(
      metric: 'D1 survival',
      baselineValue: mean(d1Baseline),
      targetValue: mean(d1Target),
      difference: d1Boot.difference,
      ciLower: d1Boot.ciLower,
      ciUpper: d1Boot.ciUpper,
      significant: d1Boot.significant,
    ));
  }

  // 2. Sessions per player
  final sessTarget = [for (final p in targetList) p.sessions.toDouble()];
  final sessBaseline = [for (final p in baselineList) p.sessions.toDouble()];
  final sessBoot = bootstrapCi(sessTarget, sessBaseline, mean);
  metrics.add(VersionMetricImpact(
    metric: 'Sessions / player',
    baselineValue: mean(sessBaseline),
    targetValue: mean(sessTarget),
    difference: sessBoot.difference,
    ciLower: sessBoot.ciLower,
    ciUpper: sessBoot.ciUpper,
    significant: sessBoot.significant,
  ));

  // 3. Playtime per player
  final playTarget = [for (final p in targetList) p.playtimeMin];
  final playBaseline = [for (final p in baselineList) p.playtimeMin];
  final playBoot = bootstrapCi(playTarget, playBaseline, mean);
  metrics.add(VersionMetricImpact(
    metric: 'Playtime / player (min)',
    baselineValue: mean(playBaseline),
    targetValue: mean(playTarget),
    difference: playBoot.difference,
    ciLower: playBoot.ciLower,
    ciUpper: playBoot.ciUpper,
    significant: playBoot.significant,
  ));

  // 4. Level Win Rates (levels with >= 10 attempts in both versions)
  final allLevels = <int>{};
  for (final p in targetList) {
    allLevels.addAll(p.levelAttempts.keys);
  }
  for (final p in baselineList) {
    allLevels.addAll(p.levelAttempts.keys);
  }

  final sortedLevels = allLevels.toList()..sort();
  for (final lvl in sortedLevels) {
    int attempts(List<PlayerVersionData> players) => players.fold(0, (sum, p) {
          final a = p.levelAttempts[lvl];
          return sum + (a == null ? 0 : a.completes + a.fails);
        });

    if (attempts(targetList) >= 10 && attempts(baselineList) >= 10) {
      double rate(List<PlayerVersionData> players) =>
          _smoothedLevelRate(players, lvl);
      final lvlBoot = bootstrapCi(targetList, baselineList, rate);
      metrics.add(VersionMetricImpact(
        metric: 'Level $lvl win rate',
        baselineValue: rate(baselineList),
        targetValue: rate(targetList),
        difference: lvlBoot.difference,
        ciLower: lvlBoot.ciLower,
        ciUpper: lvlBoot.ciUpper,
        significant: lvlBoot.significant,
      ));
    }
  }

  return VersionImpactResult(
    targetVersion: resolvedTarget,
    targetPlayers: targetList.length,
    baselineVersion: baselineVersion,
    baselinePlayers: baselineList.length,
    metrics: metrics,
    availableVersions: eligibleVersions,
    reason: null,
  );
}

/// Refit the same empirical Beta prior used by level analysis on each player sample.
double _smoothedLevelRate(List<PlayerVersionData> players, int level) {
  final totals = <int, ({int completes, int fails})>{};
  for (final player in players) {
    for (final entry in player.levelAttempts.entries) {
      final previous = totals[entry.key] ?? (completes: 0, fails: 0);
      totals[entry.key] = (
        completes: previous.completes + entry.value.completes,
        fails: previous.fails + entry.value.fails,
      );
    }
  }
  final rates = [
    for (final a in totals.values)
      if (a.completes + a.fails >= 5) a.completes / (a.completes + a.fails),
  ];
  final (alpha, beta) = fitBetaPrior(rates);
  final a = totals[level] ?? (completes: 0, fails: 0);
  return (a.completes + alpha) / (a.completes + a.fails + alpha + beta);
}
