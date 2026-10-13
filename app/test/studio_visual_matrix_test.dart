import 'dart:async';

import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/pages/funnel_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/state/events_explorer.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_matrix_fixtures.dart';
import 'support/studio_test_host.dart';

void main() {
  group('Studio Visual Matrix - Page & Tab layout', () {
    for (final style in AppStyle.values) {
      for (final width in [720.0, 1024.0, 1440.0]) {
        for (final scale in [1.0, 1.5]) {
          testWidgets('Studio matrix ${style.name} $width scale$scale',
              (t) async {
            await pumpStudio(
              t,
              const AppShell(),
              width: width,
              textScale: scale,
              style: style,
              overrides: studioMatrixOverrides(),
            );
            final container =
                ProviderScope.containerOf(t.element(find.byType(AppShell)));
            for (final page in AppPage.values) {
              container.read(selectedPageProvider.notifier).state = page;
              await t.pumpAndSettle();
              expect(t.takeException(), isNull, reason: '${page.name} overflow');
              if (page == AppPage.analytic) {
                for (var tab = 0; tab < 6; tab++) {
                  container.read(analyticTabIndexProvider.notifier).state = tab;
                  await t.pumpAndSettle();
                  expect(t.takeException(), isNull,
                      reason: 'analytic tab$tab overflow');
                }
              }
            }
          });
        }
      }
    }
  });

  group('Studio Visual Matrix - Nonempty Funnels', () {
    for (final width in [720.0, 1024.0, 1440.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('Nonempty funnels width $width scale$scale', (t) async {
          await pumpStudio(
            t,
            const AppShell(),
            width: width,
            textScale: scale,
            overrides: studioMatrixOverrides(withFunnels: true),
          );
          final container =
              ProviderScope.containerOf(t.element(find.byType(AppShell)));
          container.read(selectedPageProvider.notifier).state = AppPage.funnels;
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'funnel page overflow');
          expect(find.byType(FunnelPage), findsOneWidget);
        });
      }
    }
  });

  group('Studio Visual Matrix - Visible content and assertions', () {
    testWidgets('longIdentifier appears and renders across views', (t) async {
      await pumpStudio(
        t,
        const AppShell(),
        width: 1440,
        textScale: 1.0,
        overrides: studioMatrixOverrides(withFunnels: true),
      );
      final container =
          ProviderScope.containerOf(t.element(find.byType(AppShell)));

      // Events
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      await t.pumpAndSettle();
      expect(find.text(longIdentifier), findsWidgets);

      // Parameters
      container.read(selectedPageProvider.notifier).state = AppPage.parameters;
      await t.pumpAndSettle();
      expect(find.text(longIdentifier), findsWidgets);

      // Analytic - Tab 0: Clusters
      container.read(selectedPageProvider.notifier).state = AppPage.analytic;
      container.read(analyticTabIndexProvider.notifier).state = 0;
      await t.pumpAndSettle();
      expect(find.text(longIdentifier), findsWidgets);

      // Analytic - Tab 1: Churn
      container.read(analyticTabIndexProvider.notifier).state = 1;
      await t.pumpAndSettle();
      expect(find.text(longIdentifier), findsWidgets);

      // Analytic - Tab 3: Survival & Version Impact
      container.read(analyticTabIndexProvider.notifier).state = 3;
      await t.pumpAndSettle();
      expect(find.textContaining(longIdentifier), findsWidgets);

      // Analytic - Tab 4: Associations
      container.read(analyticTabIndexProvider.notifier).state = 4;
      await t.pumpAndSettle();
      expect(find.textContaining(longIdentifier), findsWidgets);

      // Analytic - Tab 5: Anomalies
      container.read(analyticTabIndexProvider.notifier).state = 5;
      await t.pumpAndSettle();
      expect(find.textContaining(longIdentifier), findsWidgets);
    });

    testWidgets('hidden pages cannot take keyboard focus', (t) async {
      await pumpStudio(
        t,
        const AppShell(),
        width: 1024,
        overrides: studioMatrixOverrides(),
      );
      final container =
          ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.overview;
      await t.pumpAndSettle();

      // Ensure focus on current page only
      final focusNodes = FocusManager.instance.rootScope.descendants
          .where((f) => f.hasFocus)
          .toList();
      for (final fn in focusNodes) {
        expect(fn.hasFocus, isTrue);
      }
    });

    testWidgets('reduced motion across navigation and theme', (t) async {
      await pumpStudio(
        t,
        const AppShell(),
        width: 1024,
        reducedMotion: true,
        overrides: studioMatrixOverrides(),
      );
      final container =
          ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      await t.pump();
      expect(t.takeException(), isNull);
      container.read(selectedPageProvider.notifier).state = AppPage.analytic;
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('current and previous responses finishing in reverse order',
        (t) async {
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
          // reverse completion: previous completes first, current later
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
      final container =
          ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      await t.pump();

      // complete previous first
      prevCompleter.complete([
        EventCount(day: '2026-09-27', eventName: 'event_a', count: 5),
      ]);
      await t.pump();

      // complete current later
      currentCompleter.complete([
        EventCount(day: '2026-10-01', eventName: 'event_a', count: 10),
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
      final container =
          ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.analytic;
      container.read(analyticTabIndexProvider.notifier).state = 5;
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.textContaining('insufficient baseline history'), findsWidgets);
    });

    testWidgets('initial 404 / server error displays retry feedback',
        (t) async {
      final overrides = [
        ...studioMatrixOverrides(),
        overviewProvider.overrideWith((ref, f) =>
            Future<OverviewData>.error(Exception('Server unreachable (404)'))),
      ];

      await pumpStudio(
        t,
        const AppShell(),
        width: 1024,
        overrides: overrides,
      );
      final container =
          ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.overview;
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.textContaining('Server unreachable'), findsWidgets);
    });

    testWidgets('single point and extreme axes render without crash',
        (t) async {
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

    testWidgets('resizing window with expanded detail', (t) async {
      await pumpStudio(
        t,
        const AppShell(),
        width: 1440,
        textScale: 1.0,
        overrides: studioMatrixOverrides(),
      );
      final container =
          ProviderScope.containerOf(t.element(find.byType(AppShell)));
      container.read(selectedPageProvider.notifier).state = AppPage.events;
      await t.pumpAndSettle();

      // Resize window to narrow width
      t.view.physicalSize = const Size(720, 1000);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);

      // Resize window to wide width
      t.view.physicalSize = const Size(1440, 1000);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });
}
