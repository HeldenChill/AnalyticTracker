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
}
