import 'dart:async';
import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/widgets/funnel_drilldown_panel.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/studio_matrix_fixtures.dart';
import 'support/studio_test_host.dart';

const _filters = Filters(
    from: '2026-10-01',
    to: '2026-10-04',
    platform: 'ANDROID',
    version: '1.0',
    includeTest: true);

class _Filters extends FiltersNotifier {
  @override
  Filters build() => _filters;
}

const _definition = {
  'name': 'Onboarding',
  'windowMinutes': 1440,
  'steps': [
    {'event': 'start', 'params': []},
    {'event': 'finish', 'params': []},
  ],
};

class _Backend {
  final requests = <http.Request>[];
  String? heldPath;
  String? heldInterval;
  final held = Completer<http.Response>();
  late final api = ApiClient('http://fixture', client: MockClient((r) async {
    requests.add(r);
    if (r.url.path == heldPath &&
        (heldInterval == null ||
            (jsonDecode(r.body) as Map)['interval'] == heldInterval)) {
      return held.future;
    }
    switch (r.url.path) {
      case '/filters':
        return _json({
          'platforms': ['ANDROID'],
          'versions': ['1.0']
        });
      case '/funnels':
        return _json([
          {'id': 1, ..._definition, 'updatedAt': '2026-10-05T00:00:00Z'}
        ]);
      case '/funnels/run':
        return _json(matrixFunnelResult('start').toJson());
      case '/funnels/players':
        return players('player_old');
      case '/players/player_old/events':
        return timeline('old_action');
      default:
        throw StateError('Unexpected request ${r.method} ${r.url}');
    }
  }));
  static http.Response _json(Object body) =>
      http.Response(jsonEncode(body), 200);
  static http.Response players(String uid) => _json({
        'total': 1,
        'players': [
          {'uid': uid, 'entryTs': 1000000, 'lastTs': 2000000, 'reached': 1},
        ]
      });
  static http.Response timeline(String event) => _json([
        {
          'ts': 1500000,
          'event': event,
          'params': {'key': 'val'}
        },
      ]);
  void dispose() {
    if (!held.isCompleted) held.complete(_json([]));
    api.close();
  }
}

Future<void> _open(WidgetTester t, _Backend b, {bool timeline = false}) async {
  await pumpStudio(t, const AppShell(),
      width: 1440,
      textScale: 1,
      reducedMotion: true,
      overrides: [
        apiClientProvider.overrideWithValue(b.api),
        filtersProvider.overrideWith(_Filters.new),
        selectedPageProvider.overrideWith((ref) => AppPage.funnels),
      ]);
  final cell = find.text('−5');
  await t.ensureVisible(cell);
  await t.tap(cell);
  await t.pumpAndSettle();
  expect(find.byType(FunnelDrilldownPanel), findsOneWidget);
  if (timeline) {
    await t.tap(find.textContaining('player_old'));
    await t.pumpAndSettle();
    expect(find.text('old_action'), findsOneWidget);
  }
}

void main() {
  for (final removeShell in [false, true]) {
    testWidgets(
        'queued stale Events activation canceled by ${removeShell ? 'owner removal' : 'page reversal'} makes no request',
        (t) async {
      var countCalls = 0;
      final api = ApiClient('http://fixture', client: MockClient((r) async {
        if (r.url.path == '/filters') {
          return _Backend._json({'platforms': [], 'versions': []});
        }
        if (r.url.path == '/overview') {
          return _Backend._json({
            'kpis': {
              'dau': 10,
              'newUsers': 10,
              'sessions': 20,
              'sessionsPerDau': 2,
              'playtimeMinPerDau': 10,
              'uninstalls': 0,
            },
            'previous': null,
            'daily': []
          });
        }
        if (r.url.path == '/days') {
          return _Backend._json([
            for (final day in daysBetween('2026-09-27', '2026-10-04'))
              {'day': day, 'rowCount': 1, 'pulledAt': '2026-10-10T00:00:00Z'},
          ]);
        }
        if (r.url.path == '/events/count') {
          countCalls++;
          return _Backend._json([
            {
              'day': r.url.queryParameters['from'],
              'eventName': 'queued_event',
              'count': countCalls
            }
          ]);
        }
        throw StateError('Unexpected route ${r.url}');
      }));
      addTearDown(api.close);
      var show = true;
      late StateSetter changeHost;
      await pumpStudio(t, StatefulBuilder(builder: (context, update) {
        changeHost = update;
        return show ? const AppShell() : const SizedBox.shrink();
      }), width: 1440, textScale: 1, reducedMotion: true, overrides: [
        apiClientProvider.overrideWithValue(api),
        filtersProvider.overrideWith(_Filters.new),
        selectedPageProvider.overrideWith((ref) => AppPage.events),
      ]);
      final container =
          ProviderScope.containerOf(t.element(find.byType(AppShell)));
      expect(countCalls, 2);
      container.read(selectedPageProvider.notifier).state = AppPage.overview;
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Refresh'));
      await t.pumpAndSettle();
      expect(countCalls, 2);
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      if (removeShell) {
        changeHost(() => show = false);
      } else {
        container.read(selectedPageProvider.notifier).state = AppPage.overview;
      }
      await t.pumpAndSettle();
      expect(countCalls, 2,
          reason:
              'canceled post-frame activation must never refetch hidden query');
    });
  }
  testWidgets(
      'Events cached comparison A B A reloads only after a refresh generation',
      (t) async {
    var version = 1;
    final requests = <http.Request>[];
    final api = ApiClient('http://fixture', client: MockClient((r) async {
      requests.add(r);
      if (r.url.path == '/filters') {
        return _Backend._json({
          'platforms': ['ANDROID'],
          'versions': ['1.0']
        });
      }
      if (r.url.path == '/days') {
        return _Backend._json([
          for (final day in daysBetween('2026-09-27', '2026-10-04'))
            {'day': day, 'rowCount': 1, 'pulledAt': '2026-10-10T00:00:00Z'},
        ]);
      }
      if (r.url.path == '/events/count') {
        return _Backend._json([
          {
            'day': r.url.queryParameters['from'],
            'eventName': 'cached_event',
            'count': version
          },
        ]);
      }
      throw StateError('Unexpected route ${r.url}');
    }));
    addTearDown(api.close);
    await pumpStudio(t, const AppShell(),
        width: 1440,
        textScale: 1,
        reducedMotion: true,
        overrides: [
          apiClientProvider.overrideWithValue(api),
          filtersProvider.overrideWith(_Filters.new),
          selectedPageProvider.overrideWith((ref) => AppPage.events)
        ]);
    int calls() => requests.where((r) => r.url.path == '/events/count').length;
    expect(calls(), 2);
    for (final expected in [3, 3, 3]) {
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(calls(), expected);
    }
    version = 2;
    await t.tap(find.byTooltip('Refresh'));
    await t.pumpAndSettle();
    expect(calls(), 4);
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(calls(), 6,
        reason: 'cached A must refresh once after B generation changes');
    expect(find.text('2'), findsWidgets);
    await t.pumpAndSettle();
    expect(calls(), 6);
  });

  for (final previousFailure in [false, true]) {
    testWidgets(
        'Events exact ${previousFailure ? 'comparison failure warning' : 'missing day scope'}',
        (t) async {
      final pending = Completer<http.Response>();
      var previousCalls = 0;
      final requests = <http.Request>[];
      final api = ApiClient('http://fixture', client: MockClient((r) async {
        requests.add(r);
        if (r.url.path == '/filters') {
          return _Backend._json({
            'platforms': ['ANDROID'],
            'versions': ['1.0']
          });
        }
        if (r.url.path == '/days') {
          return _Backend._json([
            for (final day in daysBetween('2026-09-27', '2026-10-04'))
              if (previousFailure || day != '2026-10-03')
                {'day': day, 'rowCount': 1, 'pulledAt': '2026-10-10T00:00:00Z'},
          ]);
        }
        if (r.url.path == '/events/count') {
          final previous = r.url.queryParameters['from'] == '2026-09-27';
          if (previous && previousFailure && ++previousCalls == 2) {
            return pending.future;
          }
          return _Backend._json([
            {
              'day': r.url.queryParameters['from'],
              'eventName': 'scope_event',
              'count': previous ? 5 : 10
            }
          ]);
        }
        throw StateError('Unexpected route ${r.url}');
      }));
      addTearDown(() {
        if (!pending.isCompleted) pending.complete(_Backend._json([]));
        api.close();
      });
      await pumpStudio(t, const AppShell(),
          width: 1440,
          textScale: 1,
          reducedMotion: true,
          overrides: [
            apiClientProvider.overrideWithValue(api),
            filtersProvider.overrideWith(_Filters.new),
            selectedPageProvider.overrideWith((ref) => AppPage.events)
          ]);
      if (previousFailure) {
        await t.tap(find.byTooltip('Refresh'));
        await t.pump(const Duration(milliseconds: 50));
        expect(previousCalls, 2);
        expect(find.textContaining('Refreshed'), findsNothing);
        pending.complete(http.Response('{"error":"comparison failed"}', 500));
        await t.pumpAndSettle();
        expect(
            find.text(
                'Comparison unavailable: unable to load previous period counts.'),
            findsOneWidget);
        expect(find.text('Updated Events; some comparison data is unavailable'),
            findsOneWidget);
        expect(find.text('Refreshed Events'), findsNothing);
        expect(find.text('10'), findsWidgets);
      } else {
        expect(find.text('Missing days: 2026-10-03'), findsOneWidget);
        expect(find.text('+100.0%'), findsNothing);
        expect(find.text('Across 3 stored days'), findsOneWidget);
      }
      for (final r in requests.where((r) => r.url.path == '/events/count')) {
        expect(r.url.queryParameters, {
          'from': r.url.queryParameters['from'],
          'to': r.url.queryParameters['from'] == '2026-09-27'
              ? '2026-09-30'
              : '2026-10-04',
          'platform': 'ANDROID',
          'version': '1.0',
          'test': '1',
        });
        expect(['2026-09-27', '2026-10-01'],
            contains(r.url.queryParameters['from']));
      }
    });
  }
  for (final switchUrl in [false, true]) {
    for (final failure in [false, true]) {
      testWidgets(
          'held manual refresh ignores superseded ${switchUrl ? 'URL' : 'filters'} ${failure ? 'error' : 'success'}',
          (t) async {
        final pending = Completer<http.Response>();
        var aCalls = 0;
        http.Response overview(int value) => _Backend._json({
              'kpis': {
                'dau': value,
                'newUsers': value,
                'sessions': value * 2,
                'sessionsPerDau': 2,
                'playtimeMinPerDau': 10,
                'uninstalls': 0,
              },
              'previous': null,
              'daily': []
            });
        final a = ApiClient('http://server-a', client: MockClient((r) async {
          if (r.url.path == '/filters') {
            return _Backend._json({'platforms': [], 'versions': []});
          }
          if (r.url.path != '/overview') {
            throw StateError('Unexpected route ${r.url}');
          }
          aCalls++;
          if (aCalls == 2) return pending.future;
          return overview(aCalls == 1 ? 10 : 20);
        }));
        final b = ApiClient('http://server-b', client: MockClient((r) async {
          if (r.url.path == '/filters') {
            return _Backend._json({'platforms': [], 'versions': []});
          }
          if (r.url.path != '/overview') {
            throw StateError('Unexpected route ${r.url}');
          }
          return overview(20);
        }));
        addTearDown(() {
          if (!pending.isCompleted) pending.complete(overview(99));
          a.close();
          b.close();
        });
        await pumpStudio(t, const AppShell(),
            width: 1440,
            textScale: 1,
            reducedMotion: true,
            overrides: [
              baseUrlProvider
                  .overrideWith(() => BaseUrlNotifier('http://server-a')),
              apiClientProvider.overrideWith((ref) =>
                  ref.watch(baseUrlProvider) == 'http://server-a' ? a : b),
              filtersProvider.overrideWith(_Filters.new),
              selectedPageProvider.overrideWith((ref) => AppPage.overview),
            ]);
        await t.tap(find.byTooltip('Refresh'));
        await t.pump(const Duration(milliseconds: 50));
        expect(aCalls, 2);
        expect(find.text('Refreshed'), findsNothing);
        final container =
            ProviderScope.containerOf(t.element(find.byType(AppShell)));
        if (switchUrl) {
          container.read(baseUrlProvider.notifier).set('http://server-b');
        } else {
          container
              .read(filtersProvider.notifier)
              .setRange('2026-10-02', '2026-10-04');
        }
        for (var frame = 0;
            frame < 10 && find.text('20').evaluate().isEmpty;
            frame++) {
          await t.pump(const Duration(milliseconds: 10));
        }
        expect(find.text('20'), findsWidgets);
        pending.complete(failure
            ? http.Response('{"error":"old failure"}', 500)
            : overview(99));
        await t.pumpAndSettle();
        expect(find.text('20'), findsWidgets);
        expect(find.text('99'), findsNothing);
        expect(find.text('Refreshed'), findsNothing);
        expect(find.text('Could not refresh Overview'), findsNothing);
        expect(find.textContaining('old failure'), findsNothing);
      });
    }
  }
  for (final timeline in [false, true]) {
    for (final failure in [false, true]) {
      testWidgets(
          'visible ${timeline ? 'timeline' : 'players'} refresh waits and ${failure ? 'fails' : 'succeeds'}',
          (t) async {
        final b = _Backend();
        addTearDown(b.dispose);
        await _open(t, b, timeline: timeline);
        final path =
            timeline ? '/players/player_old/events' : '/funnels/players';
        b.heldPath = path;
        await t.tap(find.byTooltip('Refresh'));
        await t.pump(const Duration(milliseconds: 50));
        expect(b.requests.where((r) => r.url.path == path), hasLength(2));
        expect(find.textContaining('Refreshed'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        if (timeline) {
          expect(b.requests.where((r) => r.url.path == '/funnels/players'),
              hasLength(1),
              reason: 'hidden players endpoint must not refresh');
        }
        final request = b.requests.lastWhere((r) => r.url.path == path);
        if (timeline) {
          expect(request.method, 'GET');
          expect(request.url.queryParameters, {
            'fromTs': '-3599000000',
            'toTs': '86402000000',
            'test': '1',
            'limit': '300',
          });
        } else {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'def': _definition,
            'from': '2026-10-01',
            'to': '2026-10-04',
            'platform': 'ANDROID',
            'version': '1.0',
            'test': '1',
            'step': 2,
            'outcome': 'dropped',
            'limit': 100,
          });
        }
        b.held.complete(failure
            ? http.Response('{"error":"held detail failure"}', 500)
            : timeline
                ? _Backend.timeline('new_action')
                : _Backend.players('player_new'));
        await t.pumpAndSettle();
        if (failure) {
          expect(find.text('Could not refresh Funnels'), findsOneWidget);
          expect(find.text('Refreshed Funnels'), findsNothing);
          expect(find.textContaining(timeline ? 'old_action' : 'player_old'),
              findsWidgets);
          expect(find.textContaining('held detail failure'), findsWidgets);
        } else {
          expect(find.text('Refreshed Funnels'), findsOneWidget);
          expect(find.textContaining(timeline ? 'new_action' : 'player_new'),
              findsWidgets);
          expect(find.textContaining(timeline ? 'old_action' : 'player_old'),
              findsNothing);
        }
      });
    }
    testWidgets(
        'closing held ${timeline ? 'timeline' : 'players'} suppresses old completion feedback',
        (t) async {
      final b = _Backend();
      addTearDown(b.dispose);
      await _open(t, b, timeline: timeline);
      b.heldPath = timeline ? '/players/player_old/events' : '/funnels/players';
      await t.tap(find.byTooltip('Refresh'));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(find.byTooltip('Close panel'));
      await t.pump();
      expect(find.byType(FunnelDrilldownPanel), findsNothing);
      b.held.complete(timeline
          ? _Backend.timeline('new_action')
          : _Backend.players('player_new'));
      await t.pumpAndSettle();
      expect(find.textContaining('Refreshed'), findsNothing);
      expect(find.text('Could not refresh Funnels'), findsNothing);
    });
  }

  for (final superseded in [false, true]) {
    testWidgets('weekly Trend owns exact query (superseded=$superseded)',
        (t) async {
      final b = _Backend();
      addTearDown(b.dispose);
      await pumpStudio(t, const AppShell(),
          width: 1440,
          textScale: 1,
          reducedMotion: true,
          overrides: [
            apiClientProvider.overrideWithValue(b.api),
            filtersProvider.overrideWith(_Filters.new),
            selectedPageProvider.overrideWith((ref) => AppPage.funnels)
          ]);
      final dropdown = find
          .byWidgetPredicate((w) => w is DropdownButton<FunnelBreakdownBy?>);
      await t.ensureVisible(dropdown);
      await t.tap(dropdown);
      await t.pumpAndSettle();
      await t.tap(find.text('Platform').last);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Trend'));
      await t.tap(find.text('Trend'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Week'));
      await t.tap(find.text('Week'));
      await t.pumpAndSettle();
      b.heldPath = '/funnels/run';
      b.heldInterval = 'week';
      final before =
          b.requests.where((r) => r.url.path == '/funnels/run').length;
      await t.tap(find.byTooltip('Refresh'));
      await t.pump(const Duration(milliseconds: 50));
      final runs =
          b.requests.where((r) => r.url.path == '/funnels/run').toList();
      expect(runs, hasLength(before + 1));
      expect(runs.last.method, 'POST');
      expect(jsonDecode(runs.last.body), {
        'def': _definition,
        'from': '2026-10-01',
        'to': '2026-10-04',
        'platform': 'ANDROID',
        'version': '1.0',
        'test': '1',
        'interval': 'week',
        'breakdown': {'by': 'platform'}
      });
      expect(find.text('Refreshed Funnels'), findsNothing);
      if (superseded) {
        await t.ensureVisible(find.text('Day'));
        await t.tap(find.text('Day'));
        await t.pump(const Duration(milliseconds: 50));
        expect(
            jsonDecode(b.requests
                .lastWhere((r) => r.url.path == '/funnels/run')
                .body)['interval'],
            'day');
        b.held.complete(
            http.Response('{"error":"superseded week failure"}', 500));
      } else {
        b.held.complete(_Backend._json(matrixFunnelResult('start').toJson()));
      }
      await t.pumpAndSettle();
      expect(find.text('Refreshed Funnels'),
          superseded ? findsNothing : findsOneWidget);
      expect(find.text('Could not refresh Funnels'), findsNothing);
      expect(find.textContaining('superseded week failure'), findsNothing);
    });
  }

  testWidgets('segmented players sends literal breakdown and segment',
      (t) async {
    final b = _Backend();
    addTearDown(b.dispose);
    await pumpStudio(
        t,
        SizedBox(
            height: 640,
            child: FunnelDrilldownPanel(
                def: FunnelDef.fromJson(_definition),
                filters: _filters,
                step: 2,
                breakdown:
                    const FunnelBreakdown(by: FunnelBreakdownBy.platform),
                segment: 'ANDROID',
                onClose: () {})),
        width: 720,
        textScale: 1,
        reducedMotion: true,
        overrides: [
          apiClientProvider.overrideWithValue(b.api),
          selectedPageProvider.overrideWith((ref) => AppPage.funnels)
        ]);
    final request =
        b.requests.singleWhere((r) => r.url.path == '/funnels/players');
    expect(request.method, 'POST');
    expect(jsonDecode(request.body), {
      'def': _definition,
      'from': '2026-10-01',
      'to': '2026-10-04',
      'platform': 'ANDROID',
      'version': '1.0',
      'test': '1',
      'step': 2,
      'outcome': 'dropped',
      'limit': 100,
      'breakdown': {'by': 'platform'},
      'segment': 'ANDROID'
    });
    expect(find.text('Segment: ANDROID'), findsOneWidget);
  });
}
