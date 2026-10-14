import 'package:analytic_app/src/pages/analytic/analytic_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/charts/chart_motion.dart';
import 'package:analytic_app/src/widgets/charts/chart_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_matrix_fixtures.dart';

ChartMotionSnapshot _motion(WidgetTester t, String key) =>
    ChartMotion.of(t.element(find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byKey(const ValueKey('chart-motion-plot')))));

void main() {
  for (final policy in ['disableAnimations', 'accessibleNavigation']) {
    testWidgets(
        'dashboard interrupted entrance consumes $policy without replay or refetch',
        (t) async {
      t.view.physicalSize = const Size(1440, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final calls = <AppPage>[];
      final c = ProviderContainer(
          overrides: studioMatrixOverrides(
              withFunnels: true, onDashboardRequest: calls.add));
      addTearDown(c.dispose);
      var reduced = false;
      var style = AppStyle.tremor;
      late StateSetter change;
      await t.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: StatefulBuilder(builder: (context, update) {
            change = update;
            return MaterialApp(
                theme: buildTheme(style),
                themeAnimationDuration: Duration.zero,
                home: MediaQuery(
                    data: MediaQueryData(
                        disableAnimations:
                            policy == 'disableAnimations' && reduced,
                        accessibleNavigation:
                            policy == 'accessibleNavigation' && reduced),
                    child: const AppShell()));
          })));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      final initial = _motion(t, 'overview-dau-chart');
      expect(initial.running, isTrue);
      expect(initial.revealProgress, inExclusiveRange(0, 1));
      change(() => reduced = true);
      await t.pump();
      expect(_motion(t, 'overview-dau-chart').revealProgress, 1);
      expect(_motion(t, 'overview-dau-chart').running, isFalse);
      change(() => reduced = false);
      await t.pump();
      expect(_motion(t, 'overview-dau-chart').phase, ChartMotionPhase.settled);
      c.read(filtersProvider.notifier).setPlatform('ANDROID');
      await t.pumpAndSettle();
      expect(calls, [AppPage.overview, AppPage.overview]);
      c.read(selectedPageProvider.notifier).state = AppPage.retention;
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(_motion(t, 'retention-curve').running, isTrue);
      c.read(selectedPageProvider.notifier).state = AppPage.progression;
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(_motion(t, 'progression-reach-chart').running, isTrue);
      c.read(selectedPageProvider.notifier).state = AppPage.retention;
      await t.pump();
      expect(_motion(t, 'retention-curve').phase, ChartMotionPhase.settled);
      expect(_motion(t, 'retention-curve').revealProgress, 1);
      for (final page in [
        AppPage.funnels,
        AppPage.analytic,
        AppPage.overview
      ]) {
        c.read(selectedPageProvider.notifier).state = page;
        await t.pumpAndSettle();
        if (page == AppPage.analytic) {
          expect(find.byType(AnalyticPage), findsOneWidget);
        }
      }
      expect(calls, [
        AppPage.overview,
        AppPage.overview,
        AppPage.retention,
        AppPage.progression
      ]);
      expect(c.read(filtersProvider).platform, 'ANDROID');
      expect(_motion(t, 'overview-dau-chart').phase, ChartMotionPhase.settled);
      final currentState = t.state<State<ChartMotion>>(find.descendant(
          of: find.byKey(const ValueKey('overview-dau-chart')),
          matching: find.byType(ChartMotion)));
      change(() => style = AppStyle.midnight);
      await t.pumpAndSettle();
      for (final width in [1024.0, 720.0, 1440.0]) {
        t.view.physicalSize = Size(width, 1800);
        await t.pumpAndSettle();
        final resizedState = t.state<State<ChartMotion>>(find.descendant(
            of: find.byKey(const ValueKey('overview-dau-chart')),
            matching: find.byType(ChartMotion)));
        expect(identical(currentState, resizedState), isTrue);
        expect(_motion(t, 'overview-dau-chart').running, isFalse);
        expect(_motion(t, 'overview-dau-chart').revealProgress, 1);
      }
      expect(
          find.byWidgetPredicate(
              (w) => w is ClipRect && w.clipper is ChartRevealClip),
          findsNothing);
      expect(calls, [
        AppPage.overview,
        AppPage.overview,
        AppPage.retention,
        AppPage.progression
      ]);
      expect(t.takeException(), isNull);
    });
  }
}
