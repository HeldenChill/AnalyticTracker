import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    // 24 players: p00..p07 play 20 sessions with level fails, p08..p23 play 1 session.
    store.replaceDay(d1, [
      for (var i = 0; i < 24; i++) ...[
        for (var s = 0; s < (i < 8 ? 20 : 1); s++) ev(d1, i * 1000 + s, 'session_start', 'p$i'),
        if (i < 8) for (var s = 0; s < 5; s++) ev(d1, i * 1000 + 500 + s, 'level_1_fail', 'p$i'),
      ],
      // A test-device player, excluded by default.
      ev(d1, 99999, 'session_start', 'tester', {'debug_event': 1}),
    ]);
    handler = buildHandler(store);
  });
  tearDown(() => store.close());

  Future<(int, Object?)> getJson(String path) async {
    final res = await handler(Request('GET', Uri.parse('http://localhost$path')));
    return (res.statusCode, jsonDecode(await res.readAsString()));
  }

  test('GET /analysis/clusters auto k', () async {
    final (status, body) = await getJson('/analysis/clusters?from=$d1&to=$d1');
    expect(status, 200);
    final r = ClusterResult.fromJson(body as Map<String, dynamic>);
    expect(r.players, 24);
    expect(r.k, 2);
    expect(r.clusters.map((c) => c.size), [16, 8]);
    // active_days, tenure_days, playtime_min and max_level are the same for everyone.
    expect(r.features, ['sessions', 'level_fails']);
    expect(r.droppedFeatures, ['active_days', 'playtime_min', 'max_level', 'tenure_days']);
  });

  test('GET /analysis/clusters k=auto, forced k and test devices', () async {
    final (_, auto) = await getJson('/analysis/clusters?from=$d1&to=$d1&k=auto');
    expect((auto as Map)['k'], 2);
    final (_, two) = await getJson('/analysis/clusters?from=$d1&to=$d1&k=2');
    expect((two as Map)['k'], 2);
    // Only two distinct kinds of player exist, so k=3 cannot make a third
    // group: k reports the non-empty groups.
    final (_, three) = await getJson('/analysis/clusters?from=$d1&to=$d1&k=3');
    expect((three as Map)['k'], 2);
    expect((three['clusters'] as List).length, 2);
    final (_, withTest) = await getJson('/analysis/clusters?from=$d1&to=$d1&test=1');
    expect((withTest as Map)['players'], 25);
  });

  test('GET /analysis/clusters too few players', () async {
    final (status, body) = await getJson('/analysis/clusters?from=$d1&to=$d1&platform=IOS');
    expect(status, 200);
    expect(body, containsPair('reason', 'too_few_players'));
    expect(body, containsPair('players', 0));
  });

  test('GET /analysis/clusters bad k and missing range → 400', () async {
    for (final k in ['1', '9', 'abc', '2.5']) {
      final (status, body) = await getJson('/analysis/clusters?from=$d1&to=$d1&k=$k');
      expect(status, 400, reason: k);
      expect(body, {'error': 'Invalid k'});
    }
    final (status, body) = await getJson('/analysis/clusters?from=$d1');
    expect(status, 400);
    expect(body, {'error': '"to" is required'});
  });

  test('GET /analysis/churn serves ChurnResult', () async {
    const d10 = '2026-10-10';
    store.replaceDay(d10, [ev(d10, 999999, 'session_start', 'p0')]);
    final (status, body) = await getJson('/analysis/churn?from=$d1&to=$d10');
    expect(status, 200);
    final map = body as Map<String, dynamic>;
    expect(map['players'], isA<int>());
    expect(map['observable'], isA<int>());
    expect(map['churnRate'], isA<num>());
    expect(map['drivers'], isA<List>());
  });

  test('GET /analysis/churn with short range (< 8 days) returns not_observable', () async {
    final (status, body) = await getJson('/analysis/churn?from=$d1&to=$d1');
    expect(status, 200);
    final map = body as Map<String, dynamic>;
    expect(map['reason'], 'not_observable');
    expect(map['observable'], 0);
  });

  test('GET /analysis/levels serves LevelResult', () async {
    final (status, body) = await getJson('/analysis/levels?from=$d1&to=$d1');
    expect(status, 200);
    final map = body as Map<String, dynamic>;
    expect(map['players'], 24);
    expect(map['levels'], isA<List>());
    expect(map['exitEvents'], isA<List>());
    expect(map['transitions'], isA<List>());
    final parsed = LevelResult.fromJson(map);
    expect(parsed.players, 24);
  });

  test('GET /analysis/levels too few players', () async {
    final (status, body) = await getJson('/analysis/levels?from=$d1&to=$d1&platform=IOS');
    expect(status, 200);
    final map = body as Map<String, dynamic>;
    expect(map['reason'], 'too_few_players');
    expect(map['levels'], isEmpty);
  });

  test('GET /analysis/survival serves SurvivalResult', () async {
    final (status, body) = await getJson('/analysis/survival?from=$d1&to=$d1&by=platform');
    expect(status, 200);
    final map = body as Map<String, dynamic>;
    expect(map['players'], 24);
    expect(map['by'], 'platform');
    expect(map['curves'], isA<List>());
    final parsed = SurvivalResult.fromJson(map);
    expect(parsed.players, 24);
    expect(parsed.by, 'platform');
  });

  test('GET /analysis/survival rejects invalid by parameter', () async {
    final (status, body) = await getJson('/analysis/survival?from=$d1&to=$d1&by=invalid_by');
    expect(status, 400);
    expect((body as Map<String, dynamic>)['error'], 'Invalid by');
  });

  test('GET /analysis/version-impact serves VersionImpactResult', () async {
    final (status, body) = await getJson('/analysis/version-impact?from=$d1&to=$d1');
    expect(status, 200);
    final map = body as Map<String, dynamic>;
    expect(map['availableVersions'], isA<List>());
    final parsed = VersionImpactResult.fromJson(map);
    expect(parsed.availableVersions, isA<List>());
  });

  test('GET /analysis/version-impact sorts versions chronologically by global release day with semver tie-breaker', () async {
    const d0 = '2026-09-20';
    const d2 = '2026-10-02';
    // Version 1.0.0 appeared globally on d0
    store.replaceDay(d0, [
      for (var i = 0; i < 20; i++) evx(d0, i * 100, 'session_start', 'u$i', version: '1.0.0'),
    ]);
    // Version 1.0.1 on d1 (already has 24 players with 1.0.0) -> add 1.0.1
    store.replaceDay(d2, [
      for (var i = 0; i < 20; i++) evx(d2, i * 100, 'session_start', 'w$i', version: '1.0.1'),
    ]);

    final (status, body) = await getJson('/analysis/version-impact?from=$d1&to=$d2');
    expect(status, 200);
    final parsed = VersionImpactResult.fromJson(body as Map<String, dynamic>);
    // 1.0.0 appeared before 1.0.1 globally
    expect(parsed.availableVersions, ['1.0.0', '1.0.1']);
    expect(parsed.targetVersion, '1.0.1');
    expect(parsed.baselineVersion, '1.0.0');
  });
}


