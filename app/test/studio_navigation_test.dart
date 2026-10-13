import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/analytic_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/state/events_explorer.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/state/refresh.dart';
import 'package:analytic_app/src/widgets/bar_row.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super('http://fake');
  int clusterCalls = 0;
  int associationCalls = 0;

  @override
  Future<ClusterResult> clusters(Filters f) async {
    clusterCalls++;
    return const ClusterResult(
      players: 10,
      k: 2,
      silhouette: 0.5,
      features: [],
      droppedFeatures: [],
      overall: {},
      clusters: [],
      reason: null,
    );
  }

  @override
  Future<ChurnResult> churn(Filters f) async => const ChurnResult(
        players: 10,
        observable: 10,
        churned: 2,
        stayed: 8,
        excluded: 0,
        churnRate: 0.2,
        drivers: [],
        rules: [],
        reason: null,
      );

  @override
  Future<LevelResult> levels(Filters f) async => const LevelResult(
        players: 10,
        observable: 10,
        levels: [],
        exitEvents: [],
        transitions: [],
        medianHazard: 0,
        reason: null,
      );

  @override
  Future<SurvivalResult> survival(Filters f, {String by = 'version'}) async =>
      const SurvivalResult(
        players: 10,
        by: 'version',
        curves: [],
        logRank: null,
        reason: null,
      );

  @override
  Future<VersionImpactResult> versionImpact(Filters f, {String? version}) async =>
      const VersionImpactResult(
        targetVersion: '1.0',
        targetPlayers: 10,
        baselineVersion: '0.9',
        baselinePlayers: 10,
        metrics: [],
        availableVersions: ['0.9', '1.0'],
        reason: null,
      );

  @override
  Future<AssociationResult> associations(Filters f) async {
    associationCalls++;
    return const AssociationResult(
      players: 10,
      rules: [],
      reason: null,
    );
  }

  @override
  Future<AnomalyResult> anomalies(Filters f) async =>
      const AnomalyResult(
        days: 10,
        alerts: [],
        reason: null,
      );
}

void main() {
  group('Studio Navigation & Responsive Shell', () {
    testWidgets('responsive breakpoint resize preserves PageStage subtree', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(_FakeApi()),
            daysProvider.overrideWith((ref) async => const <DayStat>[]),
            eventNamesProvider.overrideWith((ref) async => const <String>[]),
            filterOptionsProvider.overrideWith((ref) async => const FilterOptions(
                  platforms: ['ANDROID'],
                  versions: ['1.0'],
                )),
            overviewProvider.overrideWith((ref, f) async => const OverviewData(
                  kpis: Kpis(
                    dau: 10,
                    newUsers: 5,
                    sessions: 20,
                    sessionsPerDau: 2,
                    playtimeMinPerDau: 15,
                    uninstalls: 0,
                  ),
                  previous: null,
                  daily: [],
                )),
            countsProvider.overrideWith((ref, q) async => const <EventCount>[]),
            savedFunnelsProvider.overrideWith((ref) async => const <SavedFunnel>[]),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PVM Analytics'), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);

      // Resize to narrow width (compact sidebar)
      tester.view.physicalSize = const Size(720, 1000);
      await tester.pumpAndSettle();

      // PVM Analytics title hidden in compact mode, but shell and content remain alive
      expect(find.text('PVM Analytics'), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Resize back to wide
      tester.view.physicalSize = const Size(1400, 1000);
      await tester.pumpAndSettle();
      expect(find.text('PVM Analytics'), findsOneWidget);
    });

    testWidgets('AnalyticPage synchronizes TabController with analyticTabIndexProvider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApi()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: AnalyticPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially Clusters tab (index 0)
      expect(container.read(analyticTabIndexProvider), 0);

      // Switch tab by tapping Survival
      await tester.tap(find.text('Survival'));
      await tester.pumpAndSettle();
      expect(container.read(analyticTabIndexProvider), 3);

      // External update to provider moves controller to Anomalies (index 5)
      container.read(analyticTabIndexProvider.notifier).state = 5;
      await tester.pumpAndSettle();

      final tabController = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(tabController.index, 5);

      // Clamping check: set out of bounds index (e.g. 10) clamps to 5
      container.read(analyticTabIndexProvider.notifier).state = 10;
      await tester.pumpAndSettle();
      expect(tabController.index, 5);
    });

    testWidgets('BarRow primary label wraps instead of ellipsis', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              child: BarRow(
                label: 'very_long_event_name_that_should_wrap_on_multiple_lines',
                value: 42,
                max: 100,
                trailing: '42',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('very_long_event_name_that_should_wrap_on_multiple_lines'));
      expect(text.softWrap, isTrue);
      expect(text.overflow, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigation retains Events search input across page switching and window resize', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(_FakeApi()),
            daysProvider.overrideWith((ref) async => const <DayStat>[]),
            eventNamesProvider.overrideWith((ref) async => const <String>['battle_start', 'login']),
            filterOptionsProvider.overrideWith((ref) async => const FilterOptions(
                  platforms: ['ANDROID'],
                  versions: ['1.0'],
                )),
            overviewProvider.overrideWith((ref, f) async => const OverviewData(
                  kpis: Kpis(
                    dau: 10,
                    newUsers: 5,
                    sessions: 20,
                    sessionsPerDau: 2,
                    playtimeMinPerDau: 15,
                    uninstalls: 0,
                  ),
                  previous: null,
                  daily: [],
                )),
            countsProvider.overrideWith((ref, q) async => const <EventCount>[]),
            eventsExplorerProvider.overrideWith((ref, q) async => const EventsPayload(
                  current: [EventCount(day: '2026-10-10', eventName: 'battle_start', count: 10)],
                  days: [],
                )),
            savedFunnelsProvider.overrideWith((ref) async => const <SavedFunnel>[]),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Events
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'battle');
      await tester.pumpAndSettle();
      expect(find.text('battle'), findsOneWidget);

      // Navigate to Analytic
      await tester.tap(find.text('Analytic'));
      await tester.pumpAndSettle();
      expect(find.text('Clusters'), findsOneWidget);

      // Navigate back to Events
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(find.text('battle'), findsOneWidget);

      tester.view.physicalSize = const Size(720, 1000);
      await tester.pumpAndSettle();
      expect(find.text('battle'), findsOneWidget);
    });

    testWidgets('Analytic opens with reduced motion without ticker exception', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(_FakeApi())],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(body: AnalyticPage()),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Analytic tab transition tolerates reduced-motion live toggle', (tester) async {
      bool reduce = false;
      late StateSetter setHost;
      await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_FakeApi())],
        child: MaterialApp(home: StatefulBuilder(builder: (context, update) {
          setHost = update;
          return MediaQuery(data: MediaQueryData(disableAnimations: reduce),
            child: const Scaffold(body: AnalyticPage()));
        })),
      ));
      await tester.pumpAndSettle();
      tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(4);
      await tester.pump(const Duration(milliseconds: 50));
      setHost(() => reduce = true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 4);
      setHost(() => reduce = false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 4);
    });

    testWidgets('interrupted tab motion keeps visible index and refresh ownership synchronized', (t) async {
      final api = _FakeApi();
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(api),
        selectedPageProvider.overrideWith((ref) => AppPage.analytic),
      ]);
      addTearDown(container.dispose);
      addTearDown(api.close);
      bool reduced = false;
      late StateSetter updateHost;
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) {
              updateHost = update;
              return MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: const Scaffold(body: AnalyticPage()),
              );
            },
          ),
        ),
      ));
      await t.pumpAndSettle();
      t.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(4);
      await t.pump(const Duration(milliseconds: 50));
      updateHost(() => reduced = true);
      await t.pumpAndSettle();
      expect(t.widget<TabBar>(find.byType(TabBar)).controller!.index, 4);
      final associationsBefore = api.associationCalls;
      await container.read(activeRequestRegistryProvider).reload(
        AppPage.analytic,
        analyticTab: container.read(analyticTabIndexProvider),
      );
      await t.pumpAndSettle();
      expect(
        api.associationCalls,
        associationsBefore + 1,
        reason: 'refresh must reload visibly selected Associations, not hidden Clusters',
      );
      expect(container.read(analyticTabIndexProvider), 4);
    });
  });
}

