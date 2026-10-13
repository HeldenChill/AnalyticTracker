import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/analytic_page.dart';
import 'package:analytic_app/src/pages/analytic/anomalies_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/page_stage.dart';
import 'package:analytic_app/src/state/events_explorer.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/state/refresh.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const f = Filters(from: '2026-10-01', to: '2026-10-04');

class ReviewApi extends ApiClient {
  ReviewApi() : super('http://review-fixture');
  int dataVersion = 1;
  int clusterCalls = 0, associationCalls = 0;
  @override
  Future<List<EventCount>> counts(String from, String to, {String? name,
    String? platform, String? version, bool includeTest = false}) async =>
      [EventCount(day: from, eventName: 'event', count: dataVersion)];
  @override
  Future<List<DayStat>> days() async => [
    for (final day in daysBetween(f.from, f.to))
      DayStat(day: day, rowCount: dataVersion, pulledAt: '2026-10-05T01:00:00Z'),
  ];
  @override
  Future<ClusterResult> clusters(Filters f) async {
    clusterCalls++;
    return const ClusterResult(players: 0, k: 0, silhouette: null,
      features: [], droppedFeatures: [], overall: {}, clusters: [], reason: 'too_few_players');
  }
  @override
  Future<AssociationResult> associations(Filters f) async {
    associationCalls++;
    return const AssociationResult(players: 0, rules: [], reason: 'too_few_players');
  }
  @override
  Future<ChurnResult> churn(Filters f) async => const ChurnResult(
    players: 0, observable: 0, churned: 0, stayed: 0, excluded: 0,
    churnRate: 0, drivers: [], rules: [], reason: 'too_few_players');
  @override
  Future<LevelResult> levels(Filters f) async => const LevelResult(
    players: 0, observable: 0, levels: [], exitEvents: [], transitions: [],
    medianHazard: 0, reason: 'too_few_players');
  @override
  Future<SurvivalResult> survival(Filters f, {String by = 'version'}) async =>
    SurvivalResult(players: 0, by: by, curves: [], logRank: null, reason: 'too_few_players');
  @override
  Future<VersionImpactResult> versionImpact(Filters f, {String? version}) async =>
    const VersionImpactResult(targetVersion: '', targetPlayers: 0, baselineVersion: '',
      baselinePlayers: 0, metrics: [], availableVersions: [], reason: 'too_few_players');
  @override
  Future<AnomalyResult> anomalies(Filters f) async => const AnomalyResult(days: 0, alerts: [], reason: 'short_range');
}

void main() {
  testWidgets('interrupted tab motion keeps visible index and refresh ownership synchronized', (t) async {
    final api = ReviewApi();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      selectedPageProvider.overrideWith((ref) => AppPage.analytic),
    ]);
    addTearDown(container.dispose);
    addTearDown(api.close);
    bool reduced = false;
    late StateSetter updateHost;
    await t.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: StatefulBuilder(builder: (context, update) {
        updateHost = update;
        return MediaQuery(data: MediaQueryData(disableAnimations: reduced),
          child: const Scaffold(body: AnalyticPage()));
      }))));
    await t.pumpAndSettle();
    t.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(4);
    await t.pump(const Duration(milliseconds: 50));
    updateHost(() => reduced = true);
    await t.pumpAndSettle();
    expect(t.widget<TabBar>(find.byType(TabBar)).controller!.index, 4);
    final associationsBefore = api.associationCalls;
    await container.read(activeRequestRegistryProvider).reload(AppPage.analytic,
      analyticTab: container.read(analyticTabIndexProvider));
    await t.pumpAndSettle();
    expect(api.associationCalls, associationsBefore + 1,
      reason: 'refresh must reload visibly selected Associations, not hidden Clusters');
    expect(container.read(analyticTabIndexProvider), 4);
  });

  testWidgets('returning to cached Events query after refresh uses fresh data', (t) async {
    final api = ReviewApi();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      selectedPageProvider.overrideWith((ref) => AppPage.events),
    ]);
    addTearDown(container.dispose);
    addTearDown(api.close);
    var compare = false;
    late StateSetter updateHost;
    await t.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (context, update) {
        updateHost = update;
        return Consumer(builder: (context, ref, child) {
          final q = (filters: f, compare: compare);
          final value = ref.watch(eventsExplorerProvider(q));
          return ActiveRequestScope(page: AppPage.events, queryKey: ('server', q),
            reload: () async {
              await ref.refresh(eventsExplorerProvider(q).future);
              return const RefreshResult();
            }, child: Text('count=${value.valueOrNull?.current.first.count}'));
        });
      })))));
    await t.pumpAndSettle();
    expect(find.text('count=1'), findsOneWidget);
    updateHost(() => compare = true);
    await t.pumpAndSettle();
    api.dataVersion = 2;
    await container.read(activeRequestRegistryProvider).reload(AppPage.events, analyticTab: 0);
    await t.pumpAndSettle();
    expect(find.text('count=2'), findsOneWidget);
    updateHost(() => compare = false);
    await t.pumpAndSettle();
    container.read(selectedPageProvider.notifier).state = AppPage.overview;
    await t.pump();
    container.read(selectedPageProvider.notifier).state = AppPage.events;
    await t.pumpAndSettle();
    expect(container.read(eventsExplorerProvider((filters: f, compare: false)))
      .requireValue.current.first.count, 2,
      reason: 'previously cached comparison-off query predates manual refresh');
  });

  for (final accessibility in [false, true]) {
    testWidgets('anomaly expansion settles midflight for ${accessibility ? 'accessible navigation' : 'reduced motion'}', (t) async {
      const alert = AnomalyAlert(series: 'sessions', day: '2026-10-08', value: 20,
        median: 10, mad: 0, z: 6, message: 'Sessions changed', history: [
          AnomalyAlertPoint(day: '2026-10-06', value: 10),
          AnomalyAlertPoint(day: '2026-10-07', value: 10),
          AnomalyAlertPoint(day: '2026-10-08', value: 20),
        ]);
      var disabled = false;
      late StateSetter updateHost;
      await t.pumpWidget(ProviderScope(overrides: [
        anomaliesProvider.overrideWith((ref, q) async => const AnomalyResult(days: 8, alerts: [alert], reason: null)),
      ], child: MaterialApp(home: StatefulBuilder(builder: (context, update) {
        updateHost = update;
        return MediaQuery(data: MediaQueryData(disableAnimations: disabled && !accessibility,
          accessibleNavigation: disabled && accessibility), child: const Scaffold(body: AnomaliesTab()));
      }))));
      await t.pumpAndSettle();
      await t.tap(find.text('Sessions changed'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final animated = find.ancestor(of: find.byType(TimeSeriesChart), matching: find.byType(AnimatedSize)).first;
      expect(t.renderObject<RenderAnimatedSize>(animated).isAnimating, isTrue);
      updateHost(() => disabled = true);
      await t.pump();
      final render = t.renderObject<RenderAnimatedSize>(animated);
      expect(render.isAnimating, isFalse, reason: 'unchanged target must settle when policy changes');
      expect(render.size.height, render.child!.size.height);
    });
  }

  testWidgets('retained stale owner reloads once on actual page activation', (t) async {
    var a = 0, b = 0;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: Scaffold(body: Consumer(builder: (context, ref, child) {
        return PageStage(index: ref.watch(selectedPageProvider).index, pages: [
          ActiveRequestScope(page: AppPage.overview, queryKey: 'a',
            reload: () async { a++; return const RefreshResult(); }, child: const Text('a')),
          ActiveRequestScope(page: AppPage.retention, queryKey: 'b',
            reload: () async { b++; return const RefreshResult(); }, child: const Text('b')),
        ]);
      })))));
    await t.pumpAndSettle();
    container.read(selectedPageProvider.notifier).state = AppPage.retention;
    await t.pumpAndSettle();
    container.read(selectedPageProvider.notifier).state = AppPage.overview;
    await t.pumpAndSettle();
    await container.read(activeRequestRegistryProvider).reload(AppPage.overview, analyticTab: 0);
    await t.pumpAndSettle();
    expect(a, 1); expect(b, 0);
    container.read(selectedPageProvider.notifier).state = AppPage.retention;
    await t.pumpAndSettle();
    expect(b, 1);
    container.read(selectedPageProvider.notifier).state = AppPage.overview;
    await t.pumpAndSettle();
    container.read(selectedPageProvider.notifier).state = AppPage.retention;
    await t.pumpAndSettle();
    expect(b, 1);
  });
}
