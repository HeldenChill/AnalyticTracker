import 'dart:async';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/analytic_page.dart';
import 'package:analytic_app/src/pages/analytic/survival_tab.dart';
import 'package:analytic_app/src/pages/funnel_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/screens/param_screen.dart';
import 'package:analytic_app/src/shell/page_stage.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/state/events_explorer.dart';
import 'package:analytic_app/src/state/refresh.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app/test/funnel_page_test.dart' as funnelFixture;
import '../../app/test/support/studio_test_host.dart';

const f = Filters(from: '2026-10-01', to: '2026-10-04');
const overview = OverviewData(kpis: Kpis(dau: 10, newUsers: 0, sessions: 0,
  sessionsPerDau: 0, playtimeMinPerDau: 0, uninstalls: 0), previous: null, daily: []);

class CountsApi extends ApiClient {
  CountsApi() : super('http://review-fixture');
  int calls = 0;
  @override
  Future<List<EventCount>> counts(String from, String to, {String? name,
    String? platform, String? version, bool includeTest = false}) async {
    calls++;
    return [EventCount(day: from, eventName: 'event', count: calls)];
  }
}

void main() {
  Future<void> pumpSurvival(WidgetTester t, {bool reducedMotion = false}) async {
    final result = SurvivalResult(players: 50, by: 'version', curves: [
      for (var i = 0; i < 5; i++) SurvivalCurve(group: 'group$i', players: 10,
        events: 2, censored: 8, medianDays: null, points: const [
          SurvivalPoint(day: 0, survival: 1, ciLower: 1, ciUpper: 1, atRisk: 10, events: 0, censored: 0),
          SurvivalPoint(day: 1, survival: 0.8, ciLower: 0.6, ciUpper: 1, atRisk: 10, events: 2, censored: 0),
        ]),
    ], logRank: null, reason: null);
    await pumpStudio(t, const SurvivalTab(), width: 1440, textScale: 1,
      reducedMotion: reducedMotion, overrides: [
        survivalProvider.overrideWith((ref, q) async => result),
        versionImpactProvider.overrideWith((ref, q) async => const VersionImpactResult(
          targetVersion: '', targetPlayers: 0, baselineVersion: '', baselinePlayers: 0,
          metrics: [], availableVersions: [], reason: 'too_few_players')),
      ]);
  }

  testWidgets('Survival repeated-color curve has rendered dash pattern', (t) async {
    await pumpSurvival(t);
    final chart = t.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData[12].dashArray, [6, 4]);
  });

  testWidgets('Survival actual renderer respects reduced motion', (t) async {
    await pumpSurvival(t, reducedMotion: true);
    final chart = t.widget<LineChart>(find.byType(LineChart));
    expect(chart.duration, Duration.zero);
  });

  testWidgets('hidden page cannot retain keyboard focus', (t) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Future<void> render(int index) => t.pumpWidget(MaterialApp(home: Scaffold(
      body: PageStage(index: index, pages: [TextField(focusNode: focus), const Text('other')]))));
    await render(0);
    focus.requestFocus();
    await t.pump();
    expect(focus.hasFocus, isTrue);
    await render(1);
    await t.pumpAndSettle();
    expect(focus.hasFocus, isFalse, reason: 'hidden page must not keep keyboard input');
  });

  testWidgets('Events refresh also refreshes coverage metadata', (t) async {
    final api = CountsApi();
    addTearDown(api.close);
    var dayCalls = 0;
    late WidgetRef shellRef;
    const q = (filters: f, compare: false);
    await t.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api),
      daysProvider.overrideWith((ref) async {
        dayCalls++;
        return [DayStat(day: f.from, rowCount: dayCalls, pulledAt: '2026-10-05T01:00:00Z')];
      }),
    ], child: MaterialApp(home: Scaffold(body: Consumer(builder: (context, ref, child) {
      shellRef = ref;
      ref.watch(eventsExplorerProvider(q));
      return ActiveRequestScope(page: AppPage.events, queryKey: q,
        reload: () async { await ref.refresh(eventsExplorerProvider(q).future); return const RefreshResult(); },
        child: const Text('events'));
    })))));
    await t.pumpAndSettle();
    expect(dayCalls, 1);
    await refreshActivePage(shellRef, AppPage.events, analyticTab: 0);
    await t.pumpAndSettle();
    expect(api.calls, 2);
    expect(dayCalls, 2, reason: 'counts refresh must not retain old coverage');
  });

  testWidgets('refresh does not refetch retained hidden page', (t) async {
    var hiddenCalls = 0;
    final container = ProviderContainer(overrides: [
      overviewProvider.overrideWith((ref, q) async => overview),
      retentionProvider.overrideWith((ref, q) async {
        hiddenCalls++;
        return const RetentionData(offsets: [], lastDataDay: null, cohorts: [], average: []);
      }),
    ]);
    addTearDown(container.dispose);
    late WidgetRef shellRef;
    Future<void> render(int index) async {
      await t.pumpWidget(UncontrolledProviderScope(container: container,
        child: MaterialApp(home: Scaffold(body: Consumer(builder: (context, ref, child) {
          shellRef = ref;
          return PageStage(index: index, pages: [
            Consumer(builder: (context, ref, child) {
              ref.watch(overviewProvider(f));
              return ActiveRequestScope(page: AppPage.overview, queryKey: f,
                reload: () async { await ref.refresh(overviewProvider(f).future); return const RefreshResult(); },
                child: const Text('overview'));
            }),
            Consumer(builder: (context, ref, child) {
              ref.watch(retentionProvider(f));
              return const Text('retention');
            }),
          ]);
        })))));
      await t.pumpAndSettle();
    }
    await render(0);
    await render(1);
    await render(0);
    final before = hiddenCalls;
    await refreshActivePage(shellRef, AppPage.overview, analyticTab: 0);
    await t.pumpAndSettle();
    expect(hiddenCalls, before, reason: 'hidden retention must not fetch on Overview refresh');
  });

  testWidgets('Analytic opens with reduced motion without ticker exception', (t) async {
    await t.pumpWidget(const ProviderScope(child: MaterialApp(home: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Scaffold(body: AnalyticPage())))));
    expect(t.takeException(), isNull);
  });

  testWidgets('first page visit respects reduced motion', (t) async {
    Future<void> render(int index) => t.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: PageStage(index: index, pages: const [Text('one'), Text('two')])))));
    await render(0);
    await render(1);
    final fade = t.widget<FadeTransition>(find.ancestor(of: find.text('two'), matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, 1, reason: 'new page must be immediately visible');
  });

  testWidgets('Parameters refresh waits for visible buckets', (t) async {
    final pending = Completer<List<ParamBucket>>();
    addTearDown(() { if (!pending.isCompleted) pending.complete(const []); });
    var bucketCalls = 0;
    var completed = false;
    await t.pumpWidget(ProviderScope(overrides: [
      eventNamesProvider.overrideWith((ref) async => ['event']),
      parameterEventProvider.overrideWith((ref) => 'event'),
      parameterKeyProvider.overrideWith((ref) => 'key'),
      paramKeysProvider.overrideWith((ref, q) async => ['key']),
      paramValuesProvider.overrideWith((ref, q) async => const []),
      paramProvider.overrideWith((ref, q) async {
        bucketCalls++;
        return bucketCalls == 1 ? const [ParamBucket(value: 'old', count: 1)] : pending.future;
      }),
    ], child: MaterialApp(home: Scaffold(body: Consumer(builder: (context, ref, child) => Column(children: [
      TextButton(onPressed: () async {
        await refreshActivePage(ref, AppPage.parameters, analyticTab: 0);
        completed = true;
      }, child: const Text('probe refresh')),
      const Expanded(child: ParamScreen()),
    ]))))));
    await t.pumpAndSettle();
    await t.tap(find.text('probe refresh'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(bucketCalls, greaterThan(1));
    expect(completed, isFalse, reason: 'visible bucket request still pending');
  });

  testWidgets('Funnel refresh waits for visible result', (t) async {
    final pending = Completer<FunnelResult>();
    addTearDown(() { if (!pending.isCompleted) pending.complete(funnelFixture.result); });
    var resultCalls = 0;
    var completed = false;
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [
      savedFunnelsProvider.overrideWith((ref) async => const [SavedFunnel(id: 1,
        name: 'Onboarding', windowMinutes: 1440, steps: funnelFixture.steps, updatedAt: 'x')]),
      funnelResultProvider.overrideWith((ref, q) async {
        resultCalls++;
        return resultCalls == 1 ? funnelFixture.result : pending.future;
      }),
    ], child: MaterialApp(home: Scaffold(body: Consumer(builder: (context, ref, child) => Column(children: [
      TextButton(onPressed: () async {
        await refreshActivePage(ref, AppPage.funnels, analyticTab: 0);
        completed = true;
      }, child: const Text('probe refresh')),
      const Expanded(child: FunnelPage()),
    ]))))));
    await t.pumpAndSettle();
    await t.tap(find.text('probe refresh'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(resultCalls, greaterThan(1));
    expect(completed, isFalse, reason: 'visible funnel analysis still pending');
  });
}
