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

  testWidgets('Events reverse completion correctly resolves counts and previous comparison', (t) async {
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
            {'day': '2026-10-01', 'rowCount': 1, 'pulledAt': '2026-10-05T00:00:00Z'},
            {'day': '2026-10-02', 'rowCount': 1, 'pulledAt': '2026-10-05T00:00:00Z'},
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

    // Complete previous first, current later (reversed order)
    prevCompleter.complete(http.Response(jsonEncode([
      {'day': '2026-09-24', 'eventName': 'event_a', 'count': 5},
    ]), 200));
    await t.pump();

    currentCompleter.complete(http.Response(jsonEncode([
      {'day': '2026-10-01', 'eventName': 'event_a', 'count': 10},
    ]), 200));
    await t.pumpAndSettle();

    expect(find.text('event_a'), findsWidgets);
    expect(find.text('10'), findsWidgets);
  });

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
}
