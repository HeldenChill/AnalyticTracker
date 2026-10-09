import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/analytic_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const result = ClusterResult(
  players: 24,
  k: 2,
  silhouette: 0.62,
  features: ['sessions', 'level_fails', 'ev:pet_buy'],
  droppedFeatures: ['max_level'],
  overall: {'sessions': 7.8, 'level_fails': 3.0, 'ev:pet_buy': 0.5},
  clusters: [
    PlayerCluster(
      label: 'Low level_fails · Low sessions',
      size: 16,
      share: 16 / 24,
      top: ['level_fails', 'sessions', 'ev:pet_buy'],
      means: {'sessions': 1.5, 'level_fails': 0.0, 'ev:pet_buy': 0.25},
      z: {'sessions': -0.7, 'level_fails': -0.71, 'ev:pet_buy': -0.2},
    ),
    PlayerCluster(
      label: 'High level_fails · High sessions',
      size: 8,
      share: 8 / 24,
      top: ['level_fails', 'sessions', 'ev:pet_buy'],
      means: {'sessions': 20.5, 'level_fails': 9.0, 'ev:pet_buy': 1.0},
      z: {'sessions': 1.4, 'level_fails': 1.41, 'ev:pet_buy': 0.4},
    ),
  ],
  reason: null,
);

Future<void> pump(WidgetTester t, ClusterResult r) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  // New key = new ProviderScope, so a second pump in one test gets the new result.
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [clustersProvider.overrideWith((ref, f) async => r)],
    child: const MaterialApp(home: Scaffold(body: AnalyticPage())),
  ));
  await t.pumpAndSettle();
}

void main() {
  test('ApiClient.clusters sends filters and parses', () async {
    const f = Filters(from: '2026-10-01', to: '2026-10-07', version: '0.3.2', includeTest: true);
    final mock = MockClient((req) async {
      expect(req.url.path, '/analysis/clusters');
      expect(req.url.queryParameters, {'from': '2026-10-01', 'to': '2026-10-07', 'version': '0.3.2', 'test': '1'});
      return http.Response(jsonEncode(result.toJson()), 200, headers: {'content-type': 'application/json'});
    });
    final r = await ApiClient('http://h:8080', client: mock).clusters(f);
    expect(r.toJson(), result.toJson());
  });

  testWidgets('Clusters tab: summary, cards, small-sample badge, heat table', (t) async {
    await pump(t, result);
    expect(find.text('Clusters'), findsOneWidget);
    expect(find.text('24 players · 2 groups · separation strong (0.62)'), findsOneWidget);
    // Label appears on the card and in the heat table.
    expect(find.text('High level_fails · High sessions'), findsNWidgets(2));
    expect(find.text('16 players · 67%'), findsOneWidget);
    expect(find.text('8 players · 33%'), findsOneWidget);
    // Only the group of 8 (< 10) gets the badge.
    expect(find.text('small sample'), findsOneWidget);
    expect(find.text('▲ level_fails  9.0 vs 3.0 avg'), findsOneWidget);
    expect(find.text('▼ sessions  1.5 vs 7.8 avg'), findsOneWidget);
    // ev: prefix hidden in card lines and table headers.
    expect(find.text('▲ pet_buy  1.0 vs 0.5 avg'), findsOneWidget);
    expect(find.text('pet_buy'), findsOneWidget);
    expect(find.text('All players'), findsOneWidget);
    expect(find.text('20.5'), findsOneWidget);
  });

  testWidgets('Clusters tab: separation words', (t) async {
    await pump(
        t,
        ClusterResult.fromJson({
          ...result.toJson(),
          'silhouette': 0.31,
        }));
    expect(find.text('24 players · 2 groups · separation ok (0.31)'), findsOneWidget);
    await pump(
        t,
        ClusterResult.fromJson({
          ...result.toJson(),
          'silhouette': 0.1,
        }));
    expect(find.text('24 players · 2 groups · separation weak (0.10)'), findsOneWidget);
  });

  testWidgets('Clusters tab: too few players and no variance', (t) async {
    const empty = ClusterResult(
        players: 7, k: 0, silhouette: null, features: [], droppedFeatures: [], overall: {}, clusters: [],
        reason: 'too_few_players');
    await pump(t, empty);
    expect(find.text('Not enough players to find groups: 7 in this range, need at least 20. Try a longer date range.'),
        findsOneWidget);
    await pump(t, ClusterResult.fromJson({...empty.toJson(), 'players': 30, 'reason': 'no_variance'}));
    expect(find.text('Every player looks the same on every feature, so there are no groups.'), findsOneWidget);
  });
}
