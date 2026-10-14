import 'dart:async';
import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/widgets/funnel_drilldown_panel.dart';
import 'package:analytic_app/src/widgets/funnel_step_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/studio_matrix_fixtures.dart';
import 'support/studio_test_host.dart';

class _StaticFiltersNotifier extends FiltersNotifier {
  _StaticFiltersNotifier(this._filters);
  final Filters _filters;
  @override
  Filters build() => _filters;
}

void main() {
  testWidgets('Parameters refresh awaits actual values and reports 500', (t) async {
    final pending = Completer<http.Response>();
    var valuesCalls = 0, filtersCalls = 0;
    final requests = <http.Request>[];
    final api = ApiClient('http://fixture', client: MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/filters':
          filtersCalls++;
          return http.Response(jsonEncode({'platforms': ['ANDROID'], 'versions': ['1.0']}), 200);
        case '/events/names':
          return http.Response(jsonEncode(['event']), 200);
        case '/events/param-keys':
          return http.Response(jsonEncode(['key']), 200);
        case '/events/param':
          valuesCalls++;
          if (valuesCalls == 1) {
            return http.Response(jsonEncode([{'value': 'old', 'count': 12}]), 200);
          }
          return pending.future;
        default:
          throw StateError('Unexpected route ${r.url.path}');
      }
    }));
    addTearDown(api.close);
    addTearDown(() {
      if (!pending.isCompleted) pending.complete(http.Response('[]', 200));
    });
    await pumpStudio(t, const AppShell(), width: 1440, textScale: 1, overrides: [
      apiClientProvider.overrideWithValue(api),
      selectedPageProvider.overrideWith((ref) => AppPage.parameters),
      parameterEventProvider.overrideWith((ref) => 'event'),
      parameterKeyProvider.overrideWith((ref) => 'key'),
    ]);
    expect(find.text('old'), findsOneWidget);
    await t.tap(find.byTooltip('Refresh'));
    await t.pump();
    expect(valuesCalls, 2);
    expect(filtersCalls, 2);
    expect(find.textContaining('Refreshed'), findsNothing);
    pending.complete(http.Response(jsonEncode({'error': 'probe failure'}), 500));
    await t.pumpAndSettle();
    expect(find.text('Could not refresh Parameters'), findsOneWidget);
    expect(find.text('Refreshed Parameters'), findsNothing);
    expect(find.text('old'), findsOneWidget);
    final values = requests.where((r) => r.url.path == '/events/param').toList();
    expect(values.length, 2);
    expect(values.last.url.queryParameters['name'], 'event');
    expect(values.last.url.queryParameters['key'], 'key');
  });

  for (final previousFirst in [false, true]) {
  testWidgets('Events exact comparison resolves in either order (previous first=$previousFirst)', (t) async {
    final currentCompleter = Completer<http.Response>();
    final prevCompleter = Completer<http.Response>();
    final requests = <http.Request>[];

    final api = ApiClient('http://fixture', client: MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/filters':
          return http.Response(jsonEncode({'platforms': ['ANDROID'], 'versions': ['1.0']}), 200);
        case '/days':
          return http.Response(jsonEncode([
            for (final day in daysBetween('2026-09-24', '2026-10-07'))
              {'day': day, 'rowCount': 1, 'pulledAt': '2026-10-10T00:00:00Z'},
          ]), 200);
        case '/events/names':
          return http.Response(jsonEncode(['event_a']), 200);
        case '/events/count':
          final from = r.url.queryParameters['from'];
          if (from == '2026-10-01') {
            return currentCompleter.future;
          } else {
            return prevCompleter.future;
          }
        default:
          throw StateError('Unexpected route ${r.url.path}');
      }
    }));
    addTearDown(api.close);
    addTearDown(() {
      if (!currentCompleter.isCompleted) currentCompleter.complete(http.Response('[]', 200));
      if (!prevCompleter.isCompleted) prevCompleter.complete(http.Response('[]', 200));
    });

    await pumpStudio(
      t,
      const AppShell(),
      width: 1440,
      textScale: 1,
      settle: false,
      overrides: [
        apiClientProvider.overrideWithValue(api),
        selectedPageProvider.overrideWith((ref) => AppPage.events),
        filtersProvider.overrideWith(
          () => _StaticFiltersNotifier(const Filters(from: '2026-10-01', to: '2026-10-07')),
        ),
      ],
    );
    await t.pump();

    final prevResponse = http.Response(jsonEncode([
      {'day': '2026-09-24', 'eventName': 'event_a', 'count': 5},
    ]), 200);
    final currentResponse = http.Response(jsonEncode([
      {'day': '2026-10-01', 'eventName': 'event_a', 'count': 10},
    ]), 200);
    if (previousFirst) {
      prevCompleter.complete(prevResponse);
    } else {
      currentCompleter.complete(currentResponse);
    }
    await t.pump();
    expect(find.text('vs previous period (5)'), findsNothing);
    if (previousFirst) {
      currentCompleter.complete(currentResponse);
    } else {
      prevCompleter.complete(prevResponse);
    }
    await t.pumpAndSettle();

    expect(find.text('event_a'), findsWidgets);
    expect(find.text('10'), findsWidgets);
    expect(find.text('vs previous period (5)'), findsOneWidget);
    expect(find.text('+100.0%'), findsWidgets);
    expect(find.text('Across 7 stored days'), findsOneWidget);
    final countRequests = requests.where((r) => r.url.path == '/events/count').toList();
    expect(countRequests.map((r) => r.url.queryParameters).toList(), unorderedEquals([
      {'from': '2026-10-01', 'to': '2026-10-07'},
      {'from': '2026-09-24', 'to': '2026-09-30'},
    ]));
    expect(find.textContaining('Missing days:'), findsNothing);
  });
  }

  testWidgets('Old URL response arriving after new URL does not overwrite active data', (t) async {
    final serverACompleter = Completer<http.Response>();
    final serverAApi = ApiClient('http://server-a', client: MockClient((r) async {
      switch (r.url.path) {
        case '/filters':
          return http.Response(jsonEncode({'platforms': ['ANDROID'], 'versions': ['1.0']}), 200);
        case '/overview':
          return serverACompleter.future;
        default:
          throw StateError('Unexpected route ${r.url.path}');
      }
    }));
    final serverBApi = ApiClient('http://server-b', client: MockClient((r) async {
      switch (r.url.path) {
        case '/filters':
          return http.Response(jsonEncode({'platforms': ['ANDROID'], 'versions': ['1.0']}), 200);
        case '/overview':
          return http.Response(jsonEncode({
            'kpis': {
              'dau': 20,
              'newUsers': 20,
              'sessions': 40,
              'sessionsPerDau': 2,
              'playtimeMinPerDau': 10,
              'uninstalls': 0,
            },
            'previous': null,
            'daily': [],
          }), 200);
        default:
          throw StateError('Unexpected route ${r.url.path}');
      }
    }));
    addTearDown(serverAApi.close);
    addTearDown(serverBApi.close);
    addTearDown(() {
      if (!serverACompleter.isCompleted) serverACompleter.complete(http.Response('{}', 200));
    });

    await pumpStudio(t, const AppShell(), width: 1440, textScale: 1, overrides: [
      baseUrlProvider.overrideWith(() => BaseUrlNotifier('http://server-a')),
      apiClientProvider.overrideWith((ref) {
        final url = ref.watch(baseUrlProvider);
        return url == 'http://server-a' ? serverAApi : serverBApi;
      }),
      selectedPageProvider.overrideWith((ref) => AppPage.overview),
    ]);

    final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));

    // Switch to Server B
    container.read(baseUrlProvider.notifier).set('http://server-b');
    await t.pumpAndSettle();

    // Server B loaded value 20
    expect(find.text('20'), findsWidgets);

    // Now Server A finishes late with old value 5
    serverACompleter.complete(http.Response(jsonEncode({
      'kpis': {
        'dau': 5,
        'newUsers': 5,
        'sessions': 10,
        'sessionsPerDau': 2,
        'playtimeMinPerDau': 10,
        'uninstalls': 0,
      },
      'previous': null,
      'daily': [],
    }), 200));
    await t.pumpAndSettle();

    // Server B value 20 remains visible, Server A value 5 is not shown
    expect(find.text('20'), findsWidgets);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('Funnel run refresh awaits completion and 500 blocks success snackbar', (t) async {
    final pendingRun = Completer<http.Response>();
    var runCalls = 0;
    final requests = <http.Request>[];


    final api = ApiClient('http://fixture', client: MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/filters':
          return http.Response(jsonEncode({'platforms': ['ANDROID'], 'versions': ['1.0']}), 200);
        case '/funnels':
          return http.Response(jsonEncode([
            {
              'id': 1,
              'name': 'Onboarding',
              'windowMinutes': 1440,
              'steps': [
                {'event': 'start'},
                {'event': 'finish'},
              ],
              'updatedAt': '2026-10-05T00:00:00Z',
            }
          ]), 200);
        case '/funnels/run':
          runCalls++;
          if (runCalls == 1) {
            return http.Response(jsonEncode(matrixFunnelResult('start').toJson()), 200);
          }
          return pendingRun.future;
        default:
          throw StateError('Unexpected route ${r.url.path}');
      }
    }));
    addTearDown(api.close);
    addTearDown(() {
      if (!pendingRun.isCompleted) pendingRun.complete(http.Response('{}', 200));
    });

    await pumpStudio(t, const AppShell(), width: 1440, textScale: 1, overrides: [
      apiClientProvider.overrideWithValue(api),
      selectedPageProvider.overrideWith((ref) => AppPage.funnels),
    ]);
    await t.pumpAndSettle();

    expect(find.text('Onboarding'), findsWidgets);
    expect(find.byType(FunnelStepTable), findsOneWidget);

    // Refresh funnels
    await t.tap(find.byTooltip('Refresh'));
    await t.pump();
    expect(runCalls, 2);
    expect(find.textContaining('Refreshed'), findsNothing);

    // Second call fails with 500
    pendingRun.complete(http.Response(jsonEncode({'error': 'run failure'}), 500));
    await t.pumpAndSettle();

    expect(find.text('Could not refresh Funnels'), findsOneWidget);
    expect(find.text('Refreshed Funnels'), findsNothing);
  });

  testWidgets('Funnel players list and timeline request exact arguments without querying hidden list', (t) async {
    final requests = <http.Request>[];
    var playersCalls = 0;
    var timelineCalls = 0;

    final api = ApiClient('http://fixture', client: MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/filters':
          return http.Response(jsonEncode({'platforms': ['ANDROID'], 'versions': ['1.0']}), 200);
        case '/funnels':
          return http.Response(jsonEncode([
            {
              'id': 1,
              'name': 'Onboarding',
              'windowMinutes': 1440,
              'steps': [
                {'event': 'start'},
                {'event': 'finish'},
              ],
              'updatedAt': '2026-10-05T00:00:00Z',
            }
          ]), 200);
        case '/funnels/run':
          return http.Response(jsonEncode(matrixFunnelResult('start').toJson()), 200);
        case '/funnels/players':
          playersCalls++;
          return http.Response(jsonEncode({
            'total': 1,
            'players': [
              {
                'uid': 'player_1234567890',
                'entryTs': 1000000,
                'lastTs': 2000000,
                'reached': 1,
              },
            ],
          }), 200);
        case '/players/player_1234567890/events':
          timelineCalls++;
          return http.Response(jsonEncode([
            {
              'ts': 1500000,
              'event': 'start',
              'params': {'key': 'val'},
            },
          ]), 200);
        default:
          throw StateError('Unexpected route ${r.url.path}');
      }
    }));
    addTearDown(api.close);

    await pumpStudio(t, const AppShell(), width: 1440, textScale: 1, overrides: [
      apiClientProvider.overrideWithValue(api),
      selectedPageProvider.overrideWith((ref) => AppPage.funnels),
    ]);
    await t.pumpAndSettle();

    // Click dropped cell −5 to open player drilldown
    final dropCell = find.text('−5');
    await t.ensureVisible(dropCell);
    await t.pumpAndSettle();
    await t.tap(dropCell);
    await t.pumpAndSettle();

    expect(find.byType(FunnelDrilldownPanel), findsOneWidget);
    expect(playersCalls, 1);
    final playerReq = requests.firstWhere((r) => r.url.path == '/funnels/players');
    final playerBody = jsonDecode(playerReq.body) as Map<String, dynamic>;
    expect(playerBody['limit'], 100);
    expect(playerBody['step'], 2);
    expect(playerBody['outcome'], 'dropped');

    // Click UID to open timeline
    final playerItem = find.textContaining('player_1234567890');
    expect(playerItem, findsOneWidget);
    await t.tap(playerItem);
    await t.pumpAndSettle();

    expect(timelineCalls, 1);
    final timelineReq = requests.firstWhere((r) => r.url.path == '/players/player_1234567890/events');
    expect(timelineReq.url.queryParameters['limit'], '300');
    expect(playersCalls, 1, reason: 'hidden players list must not re-query while timeline is displayed');
  });

  testWidgets('Metadata /filters requested exactly once per manual action across panels', (t) async {
    var filtersCalls = 0;
    final api = ApiClient('http://fixture', client: MockClient((r) async {
      switch (r.url.path) {
        case '/filters':
          filtersCalls++;
          return http.Response(jsonEncode({'platforms': ['ANDROID'], 'versions': ['1.0']}), 200);
        case '/overview':
          return http.Response(jsonEncode({
            'kpis': {
              'dau': 10,
              'newUsers': 10,
              'sessions': 20,
              'sessionsPerDau': 2,
              'playtimeMinPerDau': 10,
              'uninstalls': 0,
            },
            'previous': null,
            'daily': [],
          }), 200);
        default:
          throw StateError('Unexpected route ${r.url.path}');
      }
    }));
    addTearDown(api.close);

    await pumpStudio(t, const AppShell(), width: 1440, textScale: 1, overrides: [
      apiClientProvider.overrideWithValue(api),
      selectedPageProvider.overrideWith((ref) => AppPage.overview),
    ]);
    await t.pumpAndSettle();

    expect(filtersCalls, 1);

    // Refresh overview manually
    await t.tap(find.byTooltip('Refresh'));
    await t.pumpAndSettle();

    expect(filtersCalls, 2);
  });

  test('All production providers execute real HTTP and parse JSON via ProviderContainer', () async {
    const f = Filters(from: '2026-10-01', to: '2026-10-04', platform: 'ANDROID', version: '1.0');
    final requests = <http.Request>[];

    final api = ApiClient('http://test-host', client: MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/days':
          return http.Response(jsonEncode([
            {'day': '2026-10-01', 'rowCount': 100, 'pulledAt': '2026-10-05T00:00:00Z'}
          ]), 200);
        case '/events/names':
          return http.Response(jsonEncode(['session_start', 'level_complete']), 200);
        case '/filters':
          return http.Response(jsonEncode({'platforms': ['ANDROID'], 'versions': ['1.0']}), 200);
        case '/overview':
          return http.Response(jsonEncode({
            'kpis': {'dau': 10, 'newUsers': 2, 'sessions': 20, 'sessionsPerDau': 2, 'playtimeMinPerDau': 5, 'uninstalls': 0},
            'previous': null,
            'daily': [],
          }), 200);
        case '/retention':
          return http.Response(jsonEncode({
            'offsets': [1, 3, 7],
            'lastDataDay': '2026-10-04',
            'cohorts': [],
            'average': [0.5, 0.3, null],
          }), 200);
        case '/progression':
          return http.Response(jsonEncode({'stages': []}), 200);
        case '/events/count':
          return http.Response(jsonEncode([
            {'day': '2026-10-01', 'eventName': 'session_start', 'count': 42}
          ]), 200);
        case '/events/param':
          return http.Response(jsonEncode([
            {'value': 'val1', 'count': 10}
          ]), 200);
        case '/events/param-keys':
          return http.Response(jsonEncode(['key1', 'key2']), 200);
        case '/events/user-prop-keys':
          return http.Response(jsonEncode(['prop1', 'prop2']), 200);
        case '/funnels':
          return http.Response(jsonEncode([
            {
              'id': 1,
              'name': 'Onboarding',
              'windowMinutes': 60,
              'steps': [{'event': 'start'}, {'event': 'end'}],
              'updatedAt': '2026-10-05T00:00:00Z',
            }
          ]), 200);
        case '/funnels/run':
          return http.Response(jsonEncode(matrixFunnelResult('start').toJson()), 200);
        case '/analysis/clusters':
          return http.Response(jsonEncode({
            'players': 20,
            'k': 2,
            'silhouette': 0.5,
            'features': ['sessions'],
            'droppedFeatures': [],
            'overall': {'sessions': 2.0},
            'clusters': [],
            'reason': null,
          }), 200);
        case '/analysis/churn':
          return http.Response(jsonEncode({
            'players': 20,
            'observable': 20,
            'churned': 10,
            'stayed': 10,
            'excluded': 0,
            'churnRate': 0.5,
            'drivers': [],
            'rules': [],
            'reason': null,
          }), 200);
        case '/analysis/levels':
          return http.Response(jsonEncode({
            'players': 20,
            'observable': 20,
            'levels': [],
            'exitEvents': [],
            'transitions': [],
            'medianHazard': 0.2,
            'reason': null,
          }), 200);
        case '/analysis/survival':
          return http.Response(jsonEncode({
            'players': 20,
            'by': 'version',
            'curves': [],
            'logRank': null,
            'reason': null,
          }), 200);
        case '/analysis/version-impact':
          return http.Response(jsonEncode({
            'targetVersion': '1.0',
            'baselineVersion': '0.9',
            'targetPlayers': 20,
            'baselinePlayers': 20,
            'availableVersions': ['0.9', '1.0'],
            'metrics': [],
            'reason': null,
          }), 200);
        case '/analysis/associations':
          return http.Response(jsonEncode({
            'players': 20,
            'rules': [],
            'reason': null,
          }), 200);
        case '/analysis/anomalies':
          return http.Response(jsonEncode({
            'days': 7,
            'alerts': [],
            'reason': null,
          }), 200);
        case '/funnels/players':
          return http.Response(jsonEncode({
            'total': 1,
            'players': [
              {'uid': 'u1', 'entryTs': 1000, 'lastTs': 2000, 'reached': 1}
            ],
          }), 200);
        case '/players/u1/events':
          return http.Response(jsonEncode([
            {'ts': 1500, 'event': 'start', 'params': {}}
          ]), 200);
        default:
          throw StateError('Unexpected path ${r.url.path}');
      }
    }));
    addTearDown(api.close);

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    // 1. Days
    final days = await container.read(daysProvider.future);
    expect(days, isNotEmpty);
    expect(days.first.day, '2026-10-01');

    // 2. Event Names
    final names = await container.read(eventNamesProvider.future);
    expect(names, contains('session_start'));

    // 3. Filter Options
    final filterOptions = await container.read(filterOptionsProvider.future);
    expect(filterOptions.platforms, contains('ANDROID'));

    // 4. Overview
    final overview = await container.read(overviewProvider(f).future);
    expect(overview.kpis.dau, 10);

    // 5. Retention
    final retention = await container.read(retentionProvider(f).future);
    expect(retention.offsets, [1, 3, 7]);

    // 6. Progression
    final progression = await container.read(progressionProvider(f).future);
    expect(progression.stages, isEmpty);

    // 7. Counts
    final counts = await container.read(countsProvider((filters: f, name: 'session_start')).future);
    expect(counts.first.count, 42);

    // 8. Param
    final params = await container.read(paramProvider((filters: f, name: 'ev', key: 'k')).future);
    expect(params.first.value, 'val1');

    // 9. Param Keys
    final paramKeys = await container.read(paramKeysProvider((event: 'ev', filters: f)).future);
    expect(paramKeys, contains('key1'));

    // 10. User Prop Keys
    final userProps = await container.read(userPropKeysProvider(f).future);
    expect(userProps, contains('prop1'));

    // 11. Saved Funnels
    final funnels = await container.read(savedFunnelsProvider.future);
    expect(funnels.first.name, 'Onboarding');

    // 12. Run Funnel
    final funnelDef = FunnelDef(name: 'F', windowMinutes: 60, steps: const [FunnelStepDef(event: 'start')]);
    final funnelRun = await container.read(funnelResultProvider((def: funnelDef, filters: f, breakdown: null, interval: null)).future);
    expect(funnelRun.totalConversion, 0.5);

    // 13. Clusters
    final clusters = await container.read(clustersProvider(f).future);
    expect(clusters.players, 20);

    // 14. Churn
    final churn = await container.read(churnProvider(f).future);
    expect(churn.churnRate, 0.5);

    // 15. Levels
    final levels = await container.read(levelsProvider(f).future);
    expect(levels.medianHazard, 0.2);

    // 16. Survival
    final survival = await container.read(survivalProvider((filters: f, by: 'version')).future);
    expect(survival.by, 'version');

    // 17. Version Impact
    final impact = await container.read(versionImpactProvider((filters: f, version: '1.0')).future);
    expect(impact.targetVersion, '1.0');

    // 18. Associations
    final associations = await container.read(associationsProvider(f).future);
    expect(associations.rules, isEmpty);

    // 19. Anomalies
    final anomalies = await container.read(anomaliesProvider(f).future);
    expect(anomalies.alerts, isEmpty);

    // 20. Funnel Players
    final players = await container.read(funnelPlayersProvider((
      def: funnelDef,
      filters: f,
      step: 1,
      outcome: FunnelPlayerOutcome.dropped,
      breakdown: null,
      segment: null,
      limit: 100,
    )).future);
    expect(players.total, 1);

    // 21. Player Events
    final timeline = await container.read(playerEventsProvider((
      uid: 'u1',
      fromTs: 1000,
      toTs: 2000,
      includeTest: false,
      limit: 300,
    )).future);
    expect(timeline.first.event, 'start');
  });

  test('401 Unauthorized returns ApiException with status 401', () async {
    const f = Filters(from: '2026-10-01', to: '2026-10-04');
    final api = ApiClient('http://test-host', client: MockClient((r) async {
      return http.Response(jsonEncode({'error': 'Unauthorized access'}), 401);
    }));
    addTearDown(api.close);

    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(overviewProvider(f).future),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', 'Unauthorized access')),
    );
  });

  test('Network client failure surfaces ApiException without crashing', () async {
    const f = Filters(from: '2026-10-01', to: '2026-10-04');
    final api = ApiClient('http://test-host', client: MockClient((r) async {
      throw http.ClientException('Connection refused');
    }));
    addTearDown(api.close);

    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(clustersProvider(f).future),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('Cannot reach server'))),
    );
  });
}
