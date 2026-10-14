import 'dart:async';
import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/widgets/dashboard_chart_panel.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/studio_test_host.dart';

const _initial = Filters(from: '2026-10-01', to: '2026-10-04');

class _SeedFilters extends FiltersNotifier {
  @override
  Filters build() => _initial;
}

const _pages = [
  (
    page: AppPage.overview,
    path: '/overview',
    key: 'overview-dau-chart',
    label: 'Overview'
  ),
  (
    page: AppPage.retention,
    path: '/retention',
    key: 'retention-curve',
    label: 'Retention'
  ),
  (
    page: AppPage.progression,
    path: '/progression',
    key: 'progression-reach-chart',
    label: 'Progression'
  ),
];

Map<String, Object?> _body(String path, int value) => switch (path) {
      '/overview' => {
          'kpis': {
            'dau': value,
            'newUsers': value,
            'sessions': value * 2,
            'sessionsPerDau': 2,
            'playtimeMinPerDau': 10,
            'uninstalls': 0
          },
          'previous': null,
          'daily': [
            {
              'day': '2026-10-01',
              'dau': value,
              'newUsers': value,
              'sessions': value * 2,
              'uninstalls': 0
            }
          ],
        },
      '/retention' => {
          'offsets': [1, 3, 7, 14],
          'lastDataDay': '2026-10-14',
          'cohorts': [
            {
              'day': '2026-10-01',
              'size': 100,
              'retained': [value, 10, 0, null]
            }
          ],
          'average': [value / 100, .1, 0, null],
        },
      '/progression' => {
          'stages': [
            {
              'stage': 1,
              'players': value,
              'starts': value * 2,
              'completes': value,
              'fails': value,
              'winRate': .5,
              'attemptsPerClear': 2,
              'dropOff': null
            }
          ],
        },
      _ => throw StateError('Unexpected dashboard route $path'),
    };

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

class _Backend {
  _Backend(this.path, {this.host = 'server-a', this.value = 25}) {
    api = ApiClient('http://$host', client: MockClient((r) async {
      requests.add(r);
      if (r.url.path == '/filters') {
        return _json({
          'platforms': ['IOS', 'ANDROID'],
          'versions': ['1.0', '2.0']
        });
      }
      if (!['/overview', '/retention', '/progression'].contains(r.url.path)) {
        throw StateError('Unexpected route ${r.method} ${r.url}');
      }
      if (r.url.path == path && hold && calls(path) == 2) return pending.future;
      return _json(_body(r.url.path, value));
    }));
  }
  final String path, host;
  int value;
  bool hold = false;
  final requests = <http.Request>[];
  final pending = Completer<http.Response>();
  late final ApiClient api;
  int calls(String route) => requests.where((r) => r.url.path == route).length;
  http.Request get last => requests.lastWhere((r) => r.url.path == path);
  void dispose() {
    if (!pending.isCompleted) pending.complete(_json(_body(path, value)));
    api.close();
  }
}

Future<ProviderContainer> _open(WidgetTester t, _Backend backend, AppPage page,
    {_Backend? replacement}) async {
  await pumpStudio(t, const AppShell(),
      width: 1440,
      height: 1200,
      textScale: 1,
      reducedMotion: true,
      overrides: [
        baseUrlProvider.overrideWith(() => BaseUrlNotifier('http://server-a')),
        apiClientProvider.overrideWith((ref) =>
            ref.watch(baseUrlProvider) == 'http://server-a'
                ? backend.api
                : replacement!.api),
        filtersProvider.overrideWith(_SeedFilters.new),
        selectedPageProvider.overrideWith((ref) => page),
      ]);
  return ProviderScope.containerOf(t.element(find.byType(AppShell)));
}

double _renderedValue(WidgetTester t, String key) {
  final panel = find.byKey(ValueKey(key));
  final config = t.widget<DashboardChartPanel>(panel);
  if (config.kind.name == 'bars') {
    return t
        .widget<BarChart>(
            find.descendant(of: panel, matching: find.byType(BarChart)))
        .data
        .barGroups
        .first
        .barRods
        .first
        .toY;
  }
  return t
      .widget<LineChart>(
          find.descendant(of: panel, matching: find.byType(LineChart)))
      .data
      .lineBarsData
      .first
      .spots
      .first
      .y;
}

void main() {
  for (final entry in _pages) {
    testWidgets('${entry.label} uses exact global filter HTTP queries',
        (t) async {
      final b = _Backend(entry.path);
      addTearDown(b.dispose);
      final c = await _open(t, b, entry.page);
      expect(b.calls(entry.path), 1);
      expect(b.last.method, 'GET');
      expect(b.last.url.queryParameters,
          {'from': '2026-10-01', 'to': '2026-10-04'});
      await t.tap(find.byKey(const ValueKey('filter-platform')));
      await t.pumpAndSettle();
      await t.tap(find.text('IOS').last);
      await t.pumpAndSettle();
      expect(b.last.url.queryParameters,
          {'from': '2026-10-01', 'to': '2026-10-04', 'platform': 'IOS'});
      await t.tap(find.byKey(const ValueKey('filter-version')));
      await t.pumpAndSettle();
      await t.tap(find.text('2.0').last);
      await t.pumpAndSettle();
      expect(b.last.url.queryParameters, {
        'from': '2026-10-01',
        'to': '2026-10-04',
        'platform': 'IOS',
        'version': '2.0'
      });
      await t.tap(find.byKey(const ValueKey('filter-test-devices')));
      await t.pumpAndSettle();
      expect(b.last.url.queryParameters, {
        'from': '2026-10-01',
        'to': '2026-10-04',
        'platform': 'IOS',
        'version': '2.0',
        'test': '1'
      });
      c.read(filtersProvider.notifier).setRange('2026-10-02', '2026-10-03');
      await t.pumpAndSettle();
      expect(b.last.url.queryParameters, {
        'from': '2026-10-02',
        'to': '2026-10-03',
        'platform': 'IOS',
        'version': '2.0',
        'test': '1'
      });
      await t.tap(find.byKey(const ValueKey('filter-platform')));
      await t.pumpAndSettle();
      await t.tap(find.text('ANDROID').last);
      await t.pumpAndSettle();
      expect(b.last.url.queryParameters, {
        'from': '2026-10-02',
        'to': '2026-10-03',
        'platform': 'ANDROID',
        'version': '2.0',
        'test': '1'
      });
      expect(b.calls(entry.path), 6);
      for (final other in _pages.where((p) => p.path != entry.path)) {
        expect(b.calls(other.path), 0,
            reason: 'Inactive dashboard must not fetch');
      }
      expect(_renderedValue(t, entry.key),
          entry.page == AppPage.retention ? .25 : 25);
    });

    for (final failure in [false, true]) {
      testWidgets(
          '${entry.label} visible refresh waits and ${failure ? 'fails with retry' : 'succeeds'}',
          (t) async {
        final b = _Backend(entry.path)..hold = true;
        addTearDown(b.dispose);
        await _open(t, b, entry.page);
        final oldValue = entry.page == AppPage.retention ? .25 : 25.0;
        expect(_renderedValue(t, entry.key), oldValue);
        await t.tap(find.byKey(const ValueKey('refresh-button')));
        await t.pump(const Duration(milliseconds: 50));
        expect(b.calls(entry.path), 2);
        expect(find.textContaining('Refreshed'), findsNothing);
        expect(find.text('Updating'), findsOneWidget);
        expect(_renderedValue(t, entry.key), oldValue);
        expect(
            t
                .widget<OutlinedButton>(
                    find.byKey(const ValueKey('refresh-button')))
                .onPressed,
            isNull);
        await t.tap(find.byKey(const ValueKey('refresh-button')));
        await t.pump(const Duration(milliseconds: 30));
        expect(b.calls(entry.path), 2);
        b.pending.complete(failure
            ? http.Response('{"error":"held dashboard failure"}', 500)
            : _json(_body(entry.path, 40)));
        await t.pumpAndSettle();
        if (failure) {
          expect(find.text('Could not refresh ${entry.label}'), findsOneWidget);
          expect(find.text('held dashboard failure'), findsOneWidget);
          expect(find.textContaining('Refreshed'), findsNothing);
          expect(_renderedValue(t, entry.key), oldValue);
          b.value = 40;
          await t.tap(find.widgetWithText(OutlinedButton, 'Retry'));
          await t.pumpAndSettle();
          expect(b.calls(entry.path), 3);
          expect(find.text('held dashboard failure'), findsNothing);
        } else {
          expect(
              find.text(entry.page == AppPage.overview
                  ? 'Refreshed'
                  : 'Refreshed ${entry.label}'),
              findsOneWidget);
        }
        expect(_renderedValue(t, entry.key),
            entry.page == AppPage.retention ? .4 : 40);
        expect(b.last.url.queryParameters,
            {'from': '2026-10-01', 'to': '2026-10-04'});
        expect(b.calls('/filters'), 2);
      });
    }

    if (entry.page == AppPage.overview) {
      continue; // Existing visible_refresh_contract_test covers all Overview combinations.
    }
    for (final switchUrl in [false, true]) {
      for (final failure in [false, true]) {
        testWidgets(
            '${entry.label} superseded ${switchUrl ? 'URL' : 'filter'} ${failure ? 'error' : 'success'} is ignored',
            (t) async {
          final a = _Backend(entry.path)..hold = true;
          final b = _Backend(entry.path, host: 'server-b', value: 40);
          addTearDown(a.dispose);
          addTearDown(b.dispose);
          final c = await _open(t, a, entry.page, replacement: b);
          await t.tap(find.byKey(const ValueKey('refresh-button')));
          await t.pump(const Duration(milliseconds: 50));
          expect(a.calls(entry.path), 2);
          if (switchUrl) {
            c.read(baseUrlProvider.notifier).set('http://server-b');
          } else {
            a.value = 40;
            c
                .read(filtersProvider.notifier)
                .setRange('2026-10-02', '2026-10-04');
          }
          final wanted = entry.page == AppPage.retention ? .4 : 40.0;
          for (var i = 0; i < 20; i++) {
            await t.pump(const Duration(milliseconds: 20));
            if (find.byKey(ValueKey(entry.key)).evaluate().isNotEmpty &&
                _renderedValue(t, entry.key) == wanted) {
              break;
            }
          }
          expect(_renderedValue(t, entry.key), wanted);
          a.pending.complete(failure
              ? http.Response('{"error":"obsolete failure"}', 500)
              : _json(_body(entry.path, 99)));
          await t.pumpAndSettle();
          expect(_renderedValue(t, entry.key), wanted);
          expect(find.textContaining('Refreshed'), findsNothing);
          expect(find.text('Could not refresh ${entry.label}'), findsNothing);
          expect(find.text('obsolete failure'), findsNothing);
          expect(a.calls(entry.path), switchUrl ? 2 : 3);
          expect(b.calls(entry.path), switchUrl ? 1 : 0);
          expect(
              (switchUrl ? b : a).last.url.queryParameters,
              switchUrl
                  ? {'from': '2026-10-01', 'to': '2026-10-04'}
                  : {'from': '2026-10-02', 'to': '2026-10-04'});
        });
      }
    }
  }
}
