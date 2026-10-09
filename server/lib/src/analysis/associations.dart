import 'dart:math';

import 'package:analytic_shared/analytic_shared.dart';

/// Mines co-occurring event pairs across player item sets (spec §6).
List<AssociationRule> mineAssociations(
  List<Set<String>> playerItemSets, {
  required int totalPlayers,
  int minSupport = 5,
  double minLift = 1.5,
  double maxNegativeLift = 0.67,
  int limit = 20,
}) {
  if (totalPlayers == 0 || playerItemSets.isEmpty) return const [];

  final itemCounts = <String, int>{};
  final pairCounts = <String, Map<String, int>>{};

  for (final items in playerItemSets) {
    for (final a in items) {
      itemCounts[a] = (itemCounts[a] ?? 0) + 1;
      final aMap = pairCounts.putIfAbsent(a, () => {});
      for (final b in items) {
        if (a != b) {
          aMap[b] = (aMap[b] ?? 0) + 1;
        }
      }
    }
  }

  final candidates = <({
    String antecedent,
    String consequent,
    int support,
    double confidence,
    double lift,
    double rankScore,
    bool smallSample,
    String sentence,
  })>[];

  final n = totalPlayers.toDouble();

  for (final entryA in pairCounts.entries) {
    final a = entryA.key;
    final countA = itemCounts[a] ?? 0;
    if (countA == 0) continue;

    for (final entryB in entryA.value.entries) {
      final b = entryB.key;
      final support = entryB.value;
      if (support < minSupport) continue;

      final countB = itemCounts[b] ?? 0;
      if (countB == 0) continue;

      final confidence = support / countA;
      final pB = countB / n;
      final lift = confidence / pB;

      final isPositive = lift >= minLift;
      final isNegative = lift <= maxNegativeLift;

      if (!isPositive && !isNegative) continue;

      final rankScore = lift * log(support);
      final smallSample = support < 10;

      final sentence = lift >= 1.0
          ? 'Players who do $a are ${lift.toStringAsFixed(1)}× more likely to do $b ($support players)'
          : 'Players who do $a are ${(1.0 / lift).toStringAsFixed(1)}× less likely to do $b ($support players)';

      candidates.add((
        antecedent: a,
        consequent: b,
        support: support,
        confidence: confidence,
        lift: lift,
        rankScore: rankScore,
        smallSample: smallSample,
        sentence: sentence,
      ));
    }
  }

  candidates.sort((a, b) => b.rankScore.compareTo(a.rankScore));

  final selected = candidates.take(limit);

  return [
    for (final c in selected)
      AssociationRule(
        antecedent: c.antecedent,
        consequent: c.consequent,
        support: c.support,
        confidence: double.parse(c.confidence.toStringAsFixed(4)),
        lift: double.parse(c.lift.toStringAsFixed(4)),
        sentence: c.sentence,
        smallSample: c.smallSample,
      ),
  ];
}
