import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

/// [grinders] players with ~20 sessions and 9 level fails, [casuals] with
/// ~1 session and none. Sessions spread evenly (+0, +0.25 .. +1.75) inside
/// each group, so there are no tighter sub-groups; `pets` is the same for
/// everyone, so it is dropped.
PlayerFeatures twoGroups({int grinders = 8, int casuals = 16}) {
  final players = <String>[];
  final rows = <List<double>>[];
  for (var i = 0; i < grinders + casuals; i++) {
    final grinder = i < grinders;
    players.add('p${i.toString().padLeft(2, '0')}');
    rows.add([
      (grinder ? 20.0 : 1.0) + (i % 8) * 0.25, // sessions
      grinder ? 9.0 : 0.0, // level_fails
      3.0, // pets (constant)
    ]);
  }
  return PlayerFeatures(players, ['sessions', 'level_fails', 'pets'], rows);
}

void main() {
  test('too few players → reason, no clusters', () {
    final pf = PlayerFeatures(
      [for (var i = 0; i < 19; i++) 'p$i'],
      ['sessions'],
      [for (var i = 0; i < 19; i++) [i.toDouble()]],
    );
    final r = clusterPlayers(pf);
    expect(r.reason, 'too_few_players');
    expect(r.players, 19);
    expect(r.k, 0);
    expect(r.silhouette, isNull);
    expect(r.clusters, isEmpty);
  });

  test('every feature constant → no_variance', () {
    final pf = PlayerFeatures(
      [for (var i = 0; i < 20; i++) 'p$i'],
      ['sessions', 'level_fails'],
      [for (var i = 0; i < 20; i++) [2.0, 0.0]],
    );
    final r = clusterPlayers(pf);
    expect(r.reason, 'no_variance');
    expect(r.players, 20);
  });

  test('auto k finds the two groups, largest first, with labels and means', () {
    final r = clusterPlayers(twoGroups());
    expect(r.reason, isNull);
    expect(r.players, 24);
    expect(r.k, 2);
    expect(r.silhouette, greaterThan(0.5));
    expect(r.features, ['sessions', 'level_fails']);
    expect(r.droppedFeatures, ['pets']);
    // Overall raw means: sessions = (8 × 20.875 + 16 × 1.875) / 24 = 197 / 24.
    expect(r.overall['sessions'], closeTo(197 / 24, 1e-9));
    expect(r.overall['level_fails'], closeTo(3, 1e-9));

    final casuals = r.clusters[0];
    final grinders = r.clusters[1];
    expect(casuals.size, 16);
    expect(casuals.share, closeTo(16 / 24, 1e-9));
    expect(grinders.size, 8);
    expect(grinders.means['sessions'], closeTo(20.875, 1e-9));
    expect(grinders.means['level_fails'], 9);
    expect(casuals.means['level_fails'], 0);
    // level_fails splits the groups with no spread inside them, so its group
    // mean z (+1.414 for grinders) beats sessions, whose spread lowers it.
    expect(grinders.z['level_fails'], closeTo(1.414214, 1e-6));
    expect(grinders.z['sessions']!, lessThan(grinders.z['level_fails']!));
    expect(grinders.top, ['level_fails', 'sessions']);
    expect(grinders.label, 'High level_fails · High sessions');
    expect(casuals.label, 'Low level_fails · Low sessions');
    expect(grinders.z.keys, r.features);
  });

  test('forced k is used and reported', () {
    final r = clusterPlayers(twoGroups(), k: 3);
    expect(r.k, 3);
    expect(r.clusters.length, 3);
    expect(r.clusters.map((c) => c.size).reduce((a, b) => a + b), 24);
    // Largest first.
    expect(r.clusters[0].size >= r.clusters[1].size && r.clusters[1].size >= r.clusters[2].size, isTrue);
  });

  test('same input, same result (fixed seed)', () {
    expect(clusterPlayers(twoGroups(), k: 3).toJson(), clusterPlayers(twoGroups(), k: 3).toJson());
  });

  test('ev: prefix is dropped in labels', () {
    final players = [for (var i = 0; i < 20; i++) 'p$i'];
    final rows = [for (var i = 0; i < 20; i++) [i < 10 ? 0.0 : 5.0]];
    final r = clusterPlayers(PlayerFeatures(players, ['ev:pet_buy'], rows));
    expect(r.clusters.map((c) => c.label), containsAll(['High pet_buy', 'Low pet_buy']));
  });
}
