import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/churn_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const churnResult = ChurnResult(
  players: 100,
  observable: 80,
  churned: 20,
  stayed: 60,
  excluded: 20,
  churnRate: 0.25,
  drivers: [
    ChurnDriver(
      feature: 'level_fails',
      meanChurned: 4.0,
      meanStayed: 1.0,
      ratio: 4.0,
      cohensD: 0.95,
      churnedRate: 0.8,
      stayedRate: 0.3,
      smallSample: false,
    ),
    ChurnDriver(
      feature: 'sessions',
      meanChurned: 1.2,
      meanStayed: 3.6,
      ratio: 0.333333,
      cohensD: -0.72,
      churnedRate: 1.0,
      stayedRate: 1.0,
      smallSample: true,
    ),
  ],
  rules: [
    ChurnRule(
      text: 'IF level_fails >= 3 → 85% left (n = 15)',
      conditions: [
        ChurnRuleCondition(feature: 'level_fails', op: '>=', threshold: 3.0),
      ],
      size: 15,
      churned: 13,
      churnRate: 0.866667,
      lift: 3.466667,
    ),
  ],
  reason: null,
);

Future<void> pump(WidgetTester t, ChurnResult r) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [churnProvider.overrideWith((ref, f) async => r)],
    child: const MaterialApp(home: Scaffold(body: ChurnTab())),
  ));
  await t.pumpAndSettle();
}

void main() {
  test('ApiClient.churn sends filters and parses', () async {
    const f = Filters(from: '2026-10-01', to: '2026-10-07', version: '0.3.2', includeTest: true);
    final mock = MockClient((req) async {
      expect(req.url.path, '/analysis/churn');
      expect(req.url.queryParameters, {'from': '2026-10-01', 'to': '2026-10-07', 'version': '0.3.2', 'test': '1'});
      return http.Response(jsonEncode(churnResult.toJson()), 200, headers: {'content-type': 'application/json'});
    });
    final r = await ApiClient('http://h:8080', client: mock).churn(f);
    expect(r.toJson(), churnResult.toJson());
  });

  testWidgets('ChurnTab renders summary, drivers table, small sample badges, and rules', (t) async {
    await pump(t, churnResult);
    expect(find.text('80 observable · 20 churned (25%) · 60 stayed · 20 excluded'), findsOneWidget);
    expect(find.text('level_fails'), findsOneWidget);
    expect(find.text('sessions'), findsOneWidget);
    expect(find.text('small sample'), findsOneWidget);
    expect(find.text('IF level_fails >= 3 → 85% left (n = 15)'), findsOneWidget);
  });

  testWidgets('ChurnTab renders not_observable notice on short date range', (t) async {
    const notObs = ChurnResult(
      players: 10,
      observable: 0,
      churned: 0,
      stayed: 0,
      excluded: 10,
      churnRate: 0.0,
      drivers: [],
      rules: [],
      reason: 'not_observable',
    );
    await pump(t, notObs);
    expect(find.textContaining('Date range too short to observe churn'), findsOneWidget);
  });

  testWidgets('ChurnTab renders too_few_players notice when observable < 20', (t) async {
    const tooFew = ChurnResult(
      players: 15,
      observable: 12,
      churned: 3,
      stayed: 9,
      excluded: 3,
      churnRate: 0.25,
      drivers: [],
      rules: [],
      reason: 'too_few_players',
    );
    await pump(t, tooFew);
    expect(find.textContaining('Not enough observable players to infer rules'), findsOneWidget);
  });
}
