import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const d3 = '2026-10-03';

void main() {
  late EventStore store;

  setUp(() {
    store = EventStore.inMemory();
    store.replaceDay(d1, [
      ev(d1, 1, 'first_open', 'a'),
      ev(d1, 2, 'session_start', 'a'),
      ev(d1, 3, 'user_engagement', 'a', {'engagement_time_msec': 90000}),
      ev(d1, 4, 'level_1_start', 'a'),
      ev(d1, 5, 'level_1_fail', 'a'),
      ev(d1, 6, 'level_1_complete', 'a'),
      ev(d1, 7, 'level_2_start', 'a'),
      ev(d1, 8, 'pet_buy', 'a'),
      ev(d1, 9, 'pet_buy', 'a'),
      ev(d1, 10, 'session_start', 'b'),
      ev(d1, 11, 'tut', 'b'),
      // Test-device player: excluded by default.
      ev(d1, 12, 'session_start', 'c', {'debug_event': 1}),
      // Empty player id: never a player.
      ev(d1, 13, 'pet_buy', ''),
    ]);
    store.replaceDay(d3, [
      ev(d3, 20, 'session_start', 'a'),
      ev(d3, 21, 'user_engagement', 'a', {'engagement_time_msec': 30000}),
      ev(d3, 22, 'level_10_fail', 'a'),
      ev(d3, 23, 'screen_view', 'b'),
    ]);
  });
  tearDown(() => store.close());

  Map<String, double> row(PlayerFeatures pf, String player) =>
      {for (var j = 0; j < pf.keys.length; j++) pf.keys[j]: pf.rows[pf.players.indexOf(player)][j]};

  test('core features per player', () {
    final pf = store.playerFeatures(const Filters(from: d1, to: d3));
    expect(pf.players, ['a', 'b']);
    // pet_buy and tut reach 1 player each (< minAutoReach = 10) → no auto features.
    expect(pf.keys, coreFeatures);
    expect(row(pf, 'a'), {
      'sessions': 2,
      'active_days': 2,
      'playtime_min': 2, // (90000 + 30000) ms / 60000
      'max_level': 2, // level_2_start; level_10 only failed, so not reached
      'level_fails': 2, // level_1_fail + level_10_fail
      'tenure_days': 2, // 10-01 .. 10-03
    });
    expect(row(pf, 'b'), {
      'sessions': 1,
      'active_days': 2,
      'playtime_min': 0,
      'max_level': 0,
      'level_fails': 0,
      'tenure_days': 2,
    });
  });

  test('test devices included on request; range and platform filters apply', () {
    final withTest = store.playerFeatures(const Filters(from: d1, to: d3, includeTest: true));
    expect(withTest.players, ['a', 'b', 'c']);

    final oneDay = store.playerFeatures(const Filters(from: d3, to: d3));
    expect(oneDay.players, ['a', 'b']);
    expect(row(oneDay, 'a')['tenure_days'], 0);

    final ios = store.playerFeatures(const Filters(from: d1, to: d3, platform: 'IOS'));
    expect(ios.players, isEmpty);
  });

  test('auto features: blocklist, at least 10 players, top 10 by players', () {
    final s = EventStore.inMemory();
    addTearDown(s.close);
    // Event e<i> (i = 0..11) is done by players p0..p<9+i>, so it reaches 10 + i players.
    // rare is done by 9 players (below minAutoReach); screen_view and level_1_start
    // by everyone but are never features.
    s.replaceDay(d1, [
      for (var i = 0; i < 12; i++)
        for (var p = 0; p <= 9 + i; p++) ev(d1, i * 100 + p, 'e$i', 'p$p'),
      for (var p = 0; p < 9; p++) ev(d1, 5000 + p, 'rare', 'p$p'),
      for (var p = 0; p < 21; p++) ev(d1, 6000 + p, 'screen_view', 'p$p'),
      for (var p = 0; p < 21; p++) ev(d1, 7000 + p, 'level_1_start', 'p$p'),
    ]);
    final pf = s.playerFeatures(const Filters(from: d1, to: d1));
    expect(pf.players.length, 21);
    // e11 (21 players) .. e2 (12 players); e1, e0 fall outside the top 10.
    expect(pf.keys.skip(coreFeatures.length), [for (var i = 11; i >= 2; i--) 'ev:e$i']);
  });
}
