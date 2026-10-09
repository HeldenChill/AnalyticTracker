import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

void main() {
  test('ClusterResult round trip keeps map order and values', () {
    const r = ClusterResult(
      players: 24,
      k: 2,
      silhouette: 0.62,
      features: ['sessions', 'ev:pet_buy'],
      droppedFeatures: ['max_level'],
      overall: {'sessions': 3.5, 'ev:pet_buy': 0.25},
      clusters: [
        PlayerCluster(
          label: 'High sessions · High pet_buy',
          size: 18,
          share: 0.75,
          top: ['sessions', 'ev:pet_buy'],
          means: {'sessions': 4.0, 'ev:pet_buy': 0.5},
          z: {'sessions': 0.8, 'ev:pet_buy': 0.4},
        ),
      ],
      reason: null,
    );
    final back = ClusterResult.fromJson(roundTrip(r.toJson()));
    expect(back.toJson(), r.toJson());
    expect(back.clusters.single.means.keys, ['sessions', 'ev:pet_buy']);
  });

  test('ClusterResult with reason, null silhouette and integer JSON numbers', () {
    final r = ClusterResult.fromJson({
      'players': 5,
      'k': 0,
      'silhouette': null,
      'features': <Object>[],
      'droppedFeatures': <Object>[],
      'overall': {'sessions': 2},
      'clusters': <Object>[],
      'reason': 'too_few_players',
    });
    expect(r.silhouette, isNull);
    expect(r.reason, 'too_few_players');
    expect(r.overall['sessions'], 2.0);
    expect(r.clusters, isEmpty);
  });

  test('ChurnResult round trip with drivers and rules', () {
    const r = ChurnResult(
      players: 100,
      observable: 75,
      churned: 25,
      stayed: 50,
      excluded: 25,
      churnRate: 0.333333,
      drivers: [
        ChurnDriver(
          feature: 'level_fails',
          meanChurned: 3.5,
          meanStayed: 1.2,
          ratio: 2.916667,
          cohensD: 0.85,
          churnedRate: 0.8,
          stayedRate: 0.4,
          smallSample: false,
        ),
      ],
      rules: [
        ChurnRule(
          text: 'IF level_fails >= 3 -> 82% left (n = 17)',
          conditions: [
            ChurnRuleCondition(feature: 'level_fails', op: '>=', threshold: 3.0),
          ],
          size: 17,
          churned: 14,
          churnRate: 0.823529,
          lift: 2.470588,
        ),
      ],
      reason: null,
    );
    final back = ChurnResult.fromJson(roundTrip(r.toJson()));
    expect(back.toJson(), r.toJson());
    expect(back.drivers.single.feature, 'level_fails');
    expect(back.rules.single.conditions.single.op, '>=');
  });

  test('ChurnResult with reason: not_observable', () {
    final r = ChurnResult.fromJson({
      'players': 10,
      'observable': 0,
      'churned': 0,
      'stayed': 0,
      'excluded': 10,
      'churnRate': 0.0,
      'drivers': <Object>[],
      'rules': <Object>[],
      'reason': 'not_observable',
    });
    expect(r.reason, 'not_observable');
    expect(r.observable, 0);
    expect(r.drivers, isEmpty);
  });

  test('LevelStats, ExitEvent, EventTransition, LevelResult JSON roundtrip', () {
    const stats = LevelStats(
      level: 1,
      attempts: 20,
      completes: 15,
      fails: 5,
      rawWinRate: 0.75,
      smoothedWinRate: 0.72,
      reached: 18,
      stopped: 2,
      hazard: 0.1111,
      wall: false,
    );
    const exit = ExitEvent(
      eventName: 'level_3_fail',
      churnedCount: 10,
      stayedCount: 2,
      churnedShare: 0.5,
      stayedShare: 0.1,
      lift: 5.0,
    );
    const transition = EventTransition(
      fromEvent: 'level_3_fail',
      toEvent: 'quit',
      count: 8,
      probability: 0.8,
    );
    const result = LevelResult(
      players: 50,
      observable: 40,
      levels: [stats],
      exitEvents: [exit],
      transitions: [transition],
      medianHazard: 0.15,
      reason: null,
    );

    final json = result.toJson();
    final parsed = LevelResult.fromJson(json);

    expect(parsed.players, 50);
    expect(parsed.observable, 40);
    expect(parsed.medianHazard, 0.15);
    expect(parsed.levels.single.level, 1);
    expect(parsed.levels.single.smoothedWinRate, 0.72);
    expect(parsed.levels.single.wall, isFalse);
    expect(parsed.exitEvents.single.eventName, 'level_3_fail');
    expect(parsed.exitEvents.single.lift, 5.0);
    expect(parsed.transitions.single.toEvent, 'quit');
    expect(parsed.transitions.single.probability, 0.8);
  });
}

