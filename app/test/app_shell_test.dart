import 'dart:async';
import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/screens/counts_screen.dart';
import 'package:analytic_app/src/screens/param_screen.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const emptyKpis = Kpis(
    dau: 0,
    newUsers: 0,
    sessions: 0,
    sessionsPerDau: null,
    playtimeMinPerDau: null,
    uninstalls: 0);

void main() {
  late List<Filters> overviewCalls;

  Future<void> pumpShell(WidgetTester t, {ApiClient? api, Future<List<DayStat>> Function()? daysLoader}) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    overviewCalls = [];
    await t.pumpWidget(ProviderScope(
      overrides: [
        if (api != null) apiClientProvider.overrideWithValue(api),
        daysProvider.overrideWith((ref) async {
          ref.watch(baseUrlProvider);
          if (daysLoader != null) {
            return daysLoader();
          }
          return const <DayStat>[];
        }),
        eventNamesProvider.overrideWith((ref) async => const <String>[]),
        filterOptionsProvider.overrideWith((ref) async => const FilterOptions(
            platforms: ['ANDROID', 'IOS'], versions: ['1.0.0'])),
        overviewProvider.overrideWith((ref, f) async {
          overviewCalls.add(f);
          return OverviewData(kpis: emptyKpis, previous: null, daily: [
            for (final d in daysBetween(f.from, f.to))
              DailyMetrics(
                  day: d, dau: 0, newUsers: 0, sessions: 0, uninstalls: 0),
          ]);
        }),
        retentionProvider.overrideWith((ref, f) async => const RetentionData(
            offsets: [1, 3, 7, 14, 30],
            lastDataDay: null,
            cohorts: [],
            average: [null, null, null, null, null])),
        progressionProvider
            .overrideWith((ref, f) async => const ProgressionData(stages: [])),
        countsProvider.overrideWith((ref, q) async => const <EventCount>[]),
        savedFunnelsProvider.overrideWith((ref) async => const <SavedFunnel>[]),
        if (api == null)
          clustersProvider.overrideWith((ref, f) async => const ClusterResult(
              players: 3,
              k: 0,
              silhouette: null,
              features: [],
              droppedFeatures: [],
              overall: {},
              clusters: [],
              reason: 'too_few_players')),
      ],
      child: const MaterialApp(home: AppShell()),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('sidebar navigates between pages', (t) async {
    await pumpShell(t);
    expect(find.text('DAU (avg)'), findsOneWidget);
    for (final label in [
      'Overview',
      'Retention',
      'Progression',
      'EXPLORE',
      'Funnels',
      'Analytic',
      'Events',
      'Parameters',
      'Data health',
      'Settings'
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await t.tap(find.text('Retention'));
    await t.pumpAndSettle();
    expect(find.text('No installs (first_open) in this range'), findsOneWidget);
    await t.tap(find.text('Progression'));
    await t.pumpAndSettle();
    expect(find.textContaining('No stage events yet'), findsOneWidget);
    await t.tap(find.text('Analytic'));
    await t.pumpAndSettle();
    expect(find.textContaining('Not enough players to find groups: 3'),
        findsOneWidget);
    await t.tap(find.text('Events'));
    await t.pumpAndSettle();
    expect(find.byType(CountsScreen), findsOneWidget);
    await t.tap(find.text('Parameters'));
    await t.pumpAndSettle();
    expect(find.byType(ParamScreen), findsOneWidget);
  });

  testWidgets('preset change refetches overview', (t) async {
    await pumpShell(t);
    await t.tap(find.byTooltip('Date range'));
    await t.pumpAndSettle();
    await t.tap(find.text('Last 7 days').last);
    await t.pumpAndSettle();
    final expected = defaultFilters(DateTime.now(), days: 7);
    expect(overviewCalls.last.from, expected.from);
    expect(overviewCalls.last.to, expected.to);
  });

  testWidgets('platform filter refetches with platform', (t) async {
    await pumpShell(t);
    await t.tap(find.text('Platform: All'));
    await t.pumpAndSettle();
    await t.tap(find.text('IOS').last);
    await t.pumpAndSettle();
    expect(overviewCalls.last.platform, 'IOS');
  });

  testWidgets('refresh refetches and confirms', (t) async {
    await pumpShell(t);
    final before = overviewCalls.length;
    await t.tap(find.byTooltip('Refresh'));
    await t.pumpAndSettle();
    expect(overviewCalls.length, greaterThan(before));
    expect(find.text('Refreshed'), findsOneWidget);
  });

  testWidgets('refresh on Overview preserves inactive analysis caches until activation', (t) async {
    var revision = 1;
    final api = ApiClient('http://test', client: MockClient((request) async {
      final Object result = switch (request.url.path) {
        '/analysis/levels' => LevelResult(
                players: revision,
                observable: 0,
                levels: [],
                exitEvents: [],
                transitions: [],
                medianHazard: 0,
                reason: 'too_few_players')
            .toJson(),
        '/analysis/survival' => SurvivalResult(
                players: revision,
                by: 'version',
                curves: [],
                logRank: null,
                reason: 'too_few_players')
            .toJson(),
        '/analysis/version-impact' => VersionImpactResult(
                targetVersion: 'new',
                targetPlayers: revision,
                baselineVersion: 'old',
                baselinePlayers: revision,
                metrics: [],
                availableVersions: ['old', 'new'],
                reason: null)
            .toJson(),
        '/analysis/associations' => AssociationResult(
                players: revision, rules: [], reason: 'too_few_players')
            .toJson(),
        '/analysis/anomalies' =>
          AnomalyResult(days: revision, alerts: [], reason: null).toJson(),
        _ => throw StateError('Unexpected request ${request.url}'),
      };
      return http.Response(jsonEncode(result), 200);
    }));
    addTearDown(api.close);
    await pumpShell(t, api: api);
    final container =
        ProviderScope.containerOf(t.element(find.byType(AppShell)));
    final f = container.read(filtersProvider);
    Future<List<int>> results() async => [
          (await container.read(levelsProvider(f).future)).players,
          (await container
                  .read(survivalProvider((filters: f, by: 'version')).future))
              .players,
          (await container.read(
                  versionImpactProvider((filters: f, version: null)).future))
              .targetPlayers,
          (await container.read(associationsProvider(f).future)).players,
          (await container.read(anomaliesProvider(f).future)).days,
        ];
    expect(await results(), [1, 1, 1, 1, 1]);
    revision = 2;
    await t.tap(find.byTooltip('Refresh'));
    await t.pumpAndSettle();
    // Under BUG-0058 fix, refresh on Overview must NOT refetch inactive analysis caches
    expect(await results(), [1, 1, 1, 1, 1]);
  });

  testWidgets('Data health refresh awaits one real request and disables duplicates', (t) async {
    final pending = Completer<List<DayStat>>();
    var requests = 0;
    await pumpShell(t, daysLoader: () {
      requests++;
      return requests == 1 ? Future.value(const <DayStat>[]) : pending.future;
    });
    await t.tap(find.widgetWithText(ListTile, 'Data health'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('refresh-button')));
    await t.pump();
    expect(t.widget<IconButton>(find.byKey(const ValueKey('refresh-button'))).onPressed, isNull);
    expect(find.text('Refreshed Data health'), findsNothing);
    expect(requests, 2);
    pending.complete(const []);
    await t.pumpAndSettle();
    expect(find.text('Refreshed Data health'), findsOneWidget);
    expect(t.widget<IconButton>(find.byKey(const ValueKey('refresh-button'))).onPressed, isNotNull);
  });

  testWidgets('Analytic refresh handles slow and failing requests', (t) async {
    final pending = Completer<http.Response>();
    final api = ApiClient('http://test', client: MockClient((request) async {
      if (request.url.path == '/analysis/clusters') {
        return pending.future;
      }
      final Object result = switch (request.url.path) {
        '/analysis/levels' => const LevelResult(
                players: 1,
                observable: 0,
                levels: [],
                exitEvents: [],
                transitions: [],
                medianHazard: 0,
                reason: 'too_few_players')
            .toJson(),
        '/analysis/survival' => const SurvivalResult(
                players: 1,
                by: 'version',
                curves: [],
                logRank: null,
                reason: 'too_few_players')
            .toJson(),
        '/analysis/version-impact' => const VersionImpactResult(
                targetVersion: 'new',
                targetPlayers: 1,
                baselineVersion: 'old',
                baselinePlayers: 1,
                metrics: [],
                availableVersions: ['old', 'new'],
                reason: null)
            .toJson(),
        '/analysis/associations' => const AssociationResult(
                players: 1, rules: [], reason: 'too_few_players')
            .toJson(),
        '/analysis/anomalies' =>
          const AnomalyResult(days: 1, alerts: [], reason: null).toJson(),
        _ => const <String, dynamic>{},
      };
      return http.Response(jsonEncode(result), 200);
    }));
    addTearDown(api.close);

    await pumpShell(t, api: api);
    await t.tap(find.text('Analytic'));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Refresh'));
    await t.pump();

    expect(find.textContaining('Refreshed'), findsNothing);
    expect(t.widget<IconButton>(find.byKey(const ValueKey('refresh-button'))).onPressed, isNull);

    pending.complete(http.Response('Server failed', 500));
    await t.pumpAndSettle();

    expect(find.textContaining('Could not refresh Analytic'), findsOneWidget);
    expect(find.textContaining('Refreshed Analytic'), findsNothing);
  });
}
