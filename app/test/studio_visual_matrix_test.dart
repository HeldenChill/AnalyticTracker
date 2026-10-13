import 'dart:async';

import 'package:analytic_app/src/pages/funnel_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/state/events_explorer.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/theme/analytics_tokens.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_app/src/widgets/funnel_drilldown_panel.dart';
import 'package:analytic_app/src/widgets/funnel_step_table.dart';
import 'package:analytic_app/src/widgets/funnel_trend_view.dart';
import 'package:analytic_app/src/widgets/studio_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_matrix_fixtures.dart';
import 'support/studio_test_host.dart';
import 'support/studio_text_assertions.dart';

void main() {
  String? clipboardContent;
  setUp(() {
    clipboardContent = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        clipboardContent = (methodCall.arguments as Map)['text'] as String?;
        return null;
      }
      if (methodCall.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardContent};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Studio Visual Matrix - Page & Tab layout', () {
    for (final style in AppStyle.values) {
      for (final width in [720.0, 1024.0, 1440.0]) {
        for (final scale in [1.0, 1.5]) {
          testWidgets('Studio matrix ${style.name} $width scale$scale', (t) async {
            await pumpStudio(
              t,
              const AppShell(),
              width: width,
              textScale: scale,
              style: style,
              overrides: studioMatrixOverrides(withFunnels: true),
            );

            // Assert theme tokens match selected style
            final tokens = AnalyticsTokens.of(t.element(find.byType(AppShell)));
            final expected = palettes[style]!;
            expect(tokens.sidebar, expected.sidebar);
            expect(tokens.activeNav, expected.activeNav);
            expect(tokens.radius, expected.radius);

            // Assert Overview content and numeric rendering
            expect(find.text('Overview'), findsWidgets);
            final num10 = find.text('10');
            expect(num10, findsWidgets);
            expectCompleteSingleLine(t, num10.first);

            final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));

            // Events page: assert longIdentifier rendering
            container.read(selectedPageProvider.notifier).state = AppPage.events;
            await t.pumpAndSettle();
            expect(find.text(longIdentifier), findsWidgets);
            expectCompleteWrappedText(t, find.text(longIdentifier).first);

            // Parameters page
            container.read(selectedPageProvider.notifier).state = AppPage.parameters;
            await t.pumpAndSettle();
            expect(find.text(longIdentifier), findsWidgets);

            // Cycle remaining pages without overflow
            for (final page in [
              AppPage.retention,
              AppPage.progression,
              AppPage.funnels,
              AppPage.dataHealth,
              AppPage.settings,
            ]) {
              container.read(selectedPageProvider.notifier).state = page;
              await t.pumpAndSettle();
              expect(t.takeException(), isNull, reason: '${page.name} overflow');
            }

            // Analytic page tabs 0..5
            container.read(selectedPageProvider.notifier).state = AppPage.analytic;
            for (var tab = 0; tab < 6; tab++) {
              container.read(analyticTabIndexProvider.notifier).state = tab;
              await t.pumpAndSettle();
              expect(t.takeException(), isNull, reason: 'analytic tab$tab overflow');
            }
          });
        }
      }
    }
  });

  group('Studio Visual Matrix - Nonempty Funnels', () {
    for (final style in AppStyle.values) {
      for (final width in [720.0, 1024.0, 1440.0]) {
        for (final scale in [1.0, 1.5]) {
          testWidgets('Nonempty funnels ${style.name} width $width scale$scale', (t) async {
            await pumpStudio(
              t,
              const AppShell(),
              width: width,
              textScale: scale,
              style: style,
              overrides: studioMatrixOverrides(withFunnels: true),
            );

            final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));
            container.read(selectedPageProvider.notifier).state = AppPage.funnels;
            await t.pumpAndSettle();
            expect(find.byType(FunnelPage), findsOneWidget);

            // 1. Open Edit dialog and verify full wrapped condition/event text
            final editBtn = find.text('Edit');
            expect(editBtn, findsOneWidget);
            final sc = Scrollable.of(t.element(editBtn));
            final vp = RenderAbstractViewport.maybeOf(t.element(editBtn).renderObject!);
            final targetOffset = vp!.getOffsetToReveal(t.element(editBtn).renderObject!, 0.2).offset;
            sc.position.jumpTo(targetOffset.clamp(sc.position.minScrollExtent, sc.position.maxScrollExtent));
            await t.pump();
            await t.tap(editBtn);
            await t.pumpAndSettle();

            expect(find.text('Edit funnel'), findsOneWidget);
            expect(find.text(longIdentifier), findsWidgets);
            expectCompleteWrappedText(t, find.text(longIdentifier).first);

            // Cancel edit dialog
            await t.tap(find.text('Cancel'));
            await t.pumpAndSettle();
            expect(find.text('Edit funnel'), findsNothing);

            // 2. Show Steps and Segments
            expect(find.text('Steps'), findsWidgets);
            expect(find.text('Segments'), findsOneWidget);

            // 3. Activate dropped-player list
            final dropCell = find.text('−5');
            await t.ensureVisible(find.byType(FunnelStepTable));
            await t.pumpAndSettle();
            await t.ensureVisible(dropCell);
            await t.pumpAndSettle();
            await t.tap(dropCell);
            await t.pumpAndSettle();
            expect(find.byType(FunnelDrilldownPanel), findsOneWidget);

            // 4. Choose UID, see timeline params
            final playerItem = find.textContaining('player_1234567890');
            expect(playerItem, findsOneWidget);
            await t.ensureVisible(playerItem);
            await t.pumpAndSettle();
            await t.tap(playerItem);
            await t.pumpAndSettle();
            expect(find.textContaining(longIdentifier), findsWidgets);

            // 5. Back and close panel
            final backBtn = find.text('Back to list');
            await t.ensureVisible(find.byType(FunnelDrilldownPanel));
            await t.pumpAndSettle();
            await t.tap(backBtn);
            await t.pumpAndSettle();
            final closeBtn = find.descendant(
              of: find.byType(FunnelDrilldownPanel),
              matching: find.byIcon(Icons.close),
            );
            await t.ensureVisible(find.byType(FunnelDrilldownPanel));
            await t.pumpAndSettle();
            await t.tap(closeBtn);
            await t.pumpAndSettle();
            expect(find.byType(FunnelDrilldownPanel), findsNothing);

            // 6. Switch Trend and Week
            final trendBtn = find.text('Trend');
            await t.ensureVisible(trendBtn);
            await t.pumpAndSettle();
            await t.tap(trendBtn);
            await t.pumpAndSettle();
            expect(find.byType(FunnelTrendView), findsOneWidget);

            final weekBtn = find.text('Week');
            await t.ensureVisible(weekBtn);
            await t.pumpAndSettle();
            await t.tap(weekBtn);
            await t.pumpAndSettle();

            // Verify data / partial marker
            expect(find.textContaining('2026-10-05'), findsWidgets);

            // 7. Verify CSV clipboard exact content
            final copyCsvBtn = find.text('Copy CSV');
            await t.ensureVisible(copyCsvBtn);
            await t.pumpAndSettle();
            await t.tap(copyCsvBtn);
            await t.pump();
            final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
            expect(clipboard?.text, isNotNull);
            expect(clipboard!.text, contains('2026-10-05'));
            expect(clipboard.text, contains('true'));
          });
        }
      }
    }
  });

  group('Studio Visual Matrix - Visible content and assertions', () {
    testWidgets('Events search, detail panel, explore parameters, and back interaction', (t) async {
      await pumpStudio(
        t,
        const AppShell(),
        width: 1440,
        textScale: 1.0,
        overrides: studioMatrixOverrides(withFunnels: true),
      );
      final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));

      // Navigate to Events
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      await t.pumpAndSettle();

      // Enter search query
      await t.enterText(find.byKey(const ValueKey('events-search')), 'Reward');
      await t.pumpAndSettle();

      // Switch chart kind to Bars
      await t.tap(find.text('Bars'));
      await t.pumpAndSettle();

      // Tap event row to open detail panel
      final row = find.byKey(ValueKey('event-row-$longIdentifier')).first;
      await t.ensureVisible(row);
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('event-detail-panel')), findsOneWidget);

      // Explore parameters button navigates to Parameters page with carried selection
      final explore = find.byKey(const ValueKey('explore-parameters-btn'));
      await t.ensureVisible(explore);
      await t.tap(explore);
      await t.pumpAndSettle();
      expect(container.read(parameterEventProvider), longIdentifier);
      expect(container.read(selectedPageProvider), AppPage.parameters);

      // Return to Events: search text, chart kind Bars, and detail panel preserved
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      await t.pumpAndSettle();
      expect(find.text('Reward'), findsOneWidget);
      expect(find.byKey(const ValueKey('event-detail-panel')), findsOneWidget);
      final chart = t.widget<TimeSeriesChart>(find.byType(TimeSeriesChart).first);
      expect(chart.kind, TimeChartKind.bars);
    });

    testWidgets('hidden pages cannot take keyboard focus and offstage tickers are inactive', (t) async {
      await pumpStudio(
        t,
        const AppShell(),
        width: 1024,
        overrides: studioMatrixOverrides(),
      );
      final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));

      // Go to Events and focus search field
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      await t.pumpAndSettle();

      final searchEditable = find.descendant(
        of: find.byKey(const ValueKey('events-search')),
        matching: find.byType(EditableText),
      );
      final searchFocus = t.widget<EditableText>(searchEditable).focusNode;
      searchFocus.requestFocus();
      await t.pump();
      expect(searchFocus.hasFocus, isTrue);

      // Navigate to Retention: search node must lose focus
      container.read(selectedPageProvider.notifier).state = AppPage.retention;
      await t.pumpAndSettle();
      expect(searchFocus.hasFocus, isFalse);

      // Hidden node cannot gain focus
      searchFocus.requestFocus();
      await t.pump();
      expect(searchFocus.hasFocus, isFalse);

      // TickerMode on active page is enabled, on hidden page is disabled
      expect(TickerMode.valuesOf(t.element(find.byKey(const PageStorageKey('page-retention')))).enabled, isTrue);
      expect(TickerMode.valuesOf(t.element(find.byKey(const PageStorageKey('page-events'), skipOffstage: false))).enabled, isFalse);
    });

    testWidgets('theme toggle updates palette tokens and reduced motion handles navigation without crash', (t) async {
      var currentStyle = AppStyle.tremor;
      late StateSetter updateHost;
      await t.pumpWidget(
        ProviderScope(
          overrides: studioMatrixOverrides(),
          child: StatefulBuilder(
            builder: (context, update) {
              updateHost = update;
              return MaterialApp(
                theme: buildTheme(currentStyle),
                home: MediaQuery(
                  data: const MediaQueryData(size: Size(1024, 800), disableAnimations: true),
                  child: const Scaffold(body: AppShell()),
                ),
              );
            },
          ),
        ),
      );
      await t.pumpAndSettle();

      var tokens = AnalyticsTokens.of(t.element(find.byType(AppShell)));
      expect(tokens.sidebar, palettes[AppStyle.tremor]!.sidebar);

      // Midnight
      updateHost(() => currentStyle = AppStyle.midnight);
      await t.pumpAndSettle();
      tokens = AnalyticsTokens.of(t.element(find.byType(AppShell)));
      expect(tokens.sidebar, palettes[AppStyle.midnight]!.sidebar);

      // Shadcn
      updateHost(() => currentStyle = AppStyle.shadcn);
      await t.pumpAndSettle();
      tokens = AnalyticsTokens.of(t.element(find.byType(AppShell)));
      expect(tokens.sidebar, palettes[AppStyle.shadcn]!.sidebar);

      // Material
      updateHost(() => currentStyle = AppStyle.material);
      await t.pumpAndSettle();
      tokens = AnalyticsTokens.of(t.element(find.byType(AppShell)));
      expect(tokens.sidebar, palettes[AppStyle.material]!.sidebar);
      expect(t.takeException(), isNull);
    });

    testWidgets('current and previous responses finishing in reverse order', (t) async {
      final currentCompleter = Completer<List<EventCount>>();
      final prevCompleter = Completer<List<EventCount>>();

      final days = [
        for (final day in daysBetween('2026-09-27', '2026-10-04'))
          DayStat(day: day, rowCount: 1, pulledAt: '2026-10-05T01:00:00Z'),
      ];

      final overrides = [
        filtersProvider.overrideWith(MatrixFilters.new),
        daysProvider.overrideWith((ref) async => days),
        eventNamesProvider.overrideWith((ref) async => ['event_a']),
        filterOptionsProvider.overrideWith((ref) async =>
            const FilterOptions(platforms: ['ANDROID'], versions: ['1.0'])),
        eventsExplorerProvider.overrideWith((ref, q) async {
          final prev = await prevCompleter.future;
          final curr = await currentCompleter.future;
          return EventsPayload(current: curr, days: days, previous: prev);
        }),
      ];

      await pumpStudio(
        t,
        const AppShell(),
        width: 1024,
        overrides: overrides,
      );
      final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      await t.pump();

      // Complete previous first
      prevCompleter.complete([
        const EventCount(day: '2026-09-27', eventName: 'event_a', count: 5),
      ]);
      await t.pump();

      // Complete current later
      currentCompleter.complete([
        const EventCount(day: '2026-10-01', eventName: 'event_a', count: 10),
      ]);
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.text('event_a'), findsWidgets);
    });

    testWidgets('no-baseline anomaly state handles gracefully', (t) async {
      final overrides = [
        ...studioMatrixOverrides(),
        anomaliesProvider.overrideWith((ref, f) async => const AnomalyResult(
              days: 0,
              alerts: [],
              reason: 'Insufficient baseline history (requires 7 days)',
            )),
      ];

      await pumpStudio(
        t,
        const AppShell(),
        width: 1024,
        overrides: overrides,
      );
      final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.analytic;
      container.read(analyticTabIndexProvider.notifier).state = 5;
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.textContaining('insufficient baseline history'), findsWidgets);
    });

    testWidgets('initial 404 / server error displays retry feedback and recovers on tap', (t) async {
      var fail = true;
      final overrides = [
        ...studioMatrixOverrides(),
        overviewProvider.overrideWith((ref, f) async {
          if (fail) throw Exception('Server unreachable (404)');
          return const OverviewData(
            kpis: Kpis(
              dau: 10,
              newUsers: 10,
              sessions: 20,
              sessionsPerDau: 2,
              playtimeMinPerDau: 15,
              uninstalls: 0,
            ),
            previous: null,
            daily: [],
          );
        }),
      ];

      await pumpStudio(
        t,
        const AppShell(),
        width: 1024,
        overrides: overrides,
      );
      final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.overview;
      await t.pumpAndSettle();

      expect(find.textContaining('Server unreachable'), findsWidgets);
      final retryBtn = find.text('Retry');
      expect(retryBtn, findsOneWidget);

      fail = false;
      await t.tap(retryBtn);
      await t.pumpAndSettle();

      expect(find.textContaining('Server unreachable'), findsNothing);
      expect(find.text('10'), findsWidgets);
    });

    testWidgets('single point and extreme axes render without crash', (t) async {
      final overrides = [
        ...studioMatrixOverrides(),
        overviewProvider.overrideWith((ref, f) async => OverviewData(
              kpis: const Kpis(
                dau: 1000000,
                newUsers: 1,
                sessions: 5000000,
                sessionsPerDau: 5.0,
                playtimeMinPerDau: 100.0,
                uninstalls: 0,
              ),
              previous: const Kpis(
                dau: 1,
                newUsers: 0,
                sessions: 1,
                sessionsPerDau: 1.0,
                playtimeMinPerDau: 1.0,
                uninstalls: 0,
              ),
              daily: [
                DailyMetrics(
                  day: f.from,
                  dau: 1000000,
                  newUsers: 1,
                  sessions: 5000000,
                  uninstalls: 0,
                ),
              ],
            )),
      ];

      await pumpStudio(
        t,
        const AppShell(),
        width: 720,
        textScale: 1.5,
        overrides: overrides,
      );
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
    });

    testWidgets('resizing window with expanded detail preserves selection and detail view', (t) async {
      await pumpStudio(
        t,
        const AppShell(),
        width: 1440,
        textScale: 1.0,
        overrides: studioMatrixOverrides(withFunnels: true),
      );
      final container = ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      await t.pumpAndSettle();

      // Select event row to open detail
      final row = find.byKey(ValueKey('event-row-$longIdentifier')).first;
      await t.ensureVisible(find.byType(StudioTable));
      await t.pumpAndSettle();
      await t.ensureVisible(row);
      await t.pumpAndSettle();
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('event-detail-panel')), findsOneWidget);

      // Resize window to narrow width
      t.view.physicalSize = const Size(720, 1000);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('event-detail-panel')), findsOneWidget);

      // Resize window back to wide width
      t.view.physicalSize = const Size(1440, 1000);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('event-detail-panel')), findsOneWidget);
    });
  });
}
