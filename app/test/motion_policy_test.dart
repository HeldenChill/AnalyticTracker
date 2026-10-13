import 'package:analytic_app/main.dart';
import 'package:analytic_app/src/pages/analytic/anomalies_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/theme/motion_policy.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app root reads reduced motion before creating MaterialApp', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        daysProvider.overrideWith((ref) async => []),
        eventNamesProvider.overrideWith((ref) async => []),
        filterOptionsProvider.overrideWith(
          (ref) async => const FilterOptions(platforms: [], versions: []),
        ),
        overviewProvider.overrideWith(
          (ref, f) async => const OverviewData(
            kpis: Kpis(
              dau: 0,
              newUsers: 0,
              sessions: 0,
              sessionsPerDau: null,
              playtimeMinPerDau: null,
              uninstalls: 0,
            ),
            previous: null,
            daily: [],
          ),
        ),
      ],
      child: const MediaQuery(
        data: MediaQueryData(
          size: Size(1440, 1000),
          disableAnimations: true,
        ),
        child: AnalyticApp(),
      ),
    ));
    await t.pump();
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeAnimationDuration, Duration.zero);
  });

  testWidgets('all motion kinds obey both reduced-motion flags', (t) async {
    const milliseconds = {
      MotionKind.navigation: 180,
      MotionKind.tab: 200,
      MotionKind.expansion: 220,
      MotionKind.chartEnter: 400,
      MotionKind.chartUpdate: 350,
      MotionKind.theme: 200,
      MotionKind.hover: 120,
    };
    for (final flags in [(false, false), (true, false), (false, true)]) {
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: flags.$1,
            accessibleNavigation: flags.$2,
          ),
          child: Builder(
            builder: (context) {
              for (final entry in milliseconds.entries) {
                expect(
                  motionDuration(context, entry.key),
                  Duration(milliseconds: flags.$1 || flags.$2 ? 0 : entry.value),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ));
    }
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
      final animated = find.ancestor(of: find.byType(TimeSeriesChart), matching: find.byType(AnimatedSize));
      expect(t.renderObject<RenderAnimatedSize>(animated.first).isAnimating, isTrue);
      final targetHeight = t.renderObject<RenderAnimatedSize>(animated.first).child!.size.height;
      final chartState = t.state(find.byType(TimeSeriesChart));
      updateHost(() => disabled = true);
      await t.pump();
      if (animated.evaluate().isNotEmpty) {
        final render = t.renderObject<RenderAnimatedSize>(animated.first);
        expect(render.isAnimating, isFalse, reason: 'unchanged target must settle when policy changes');
        expect(render.size.height, targetHeight);
      } else {
        expect(t.getSize(find.byKey(const ValueKey('anomaly-expansion:sessions:2026-10-08'))).height, targetHeight);
      }
      expect(t.state(find.byType(TimeSeriesChart)), same(chartState));
    });
  }

  testWidgets('anomaly expansion settles on inactive TickerMode and expands again when re-enabled', (t) async {
    const alert = AnomalyAlert(series: 'sessions', day: '2026-10-08', value: 20,
      median: 10, mad: 0, z: 6, message: 'Sessions changed', history: [
        AnomalyAlertPoint(day: '2026-10-06', value: 10),
        AnomalyAlertPoint(day: '2026-10-07', value: 10),
        AnomalyAlertPoint(day: '2026-10-08', value: 20),
      ]);
    var tickerActive = true;
    late StateSetter updateHost;
    await t.pumpWidget(ProviderScope(overrides: [
      anomaliesProvider.overrideWith((ref, q) async => const AnomalyResult(days: 8, alerts: [alert], reason: null)),
    ], child: MaterialApp(home: StatefulBuilder(builder: (context, update) {
      updateHost = update;
      return TickerMode(enabled: tickerActive, child: const Scaffold(body: AnomaliesTab()));
    }))));
    await t.pumpAndSettle();
    await t.tap(find.text('Sessions changed'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    final animated = find.ancestor(of: find.byType(TimeSeriesChart), matching: find.byType(AnimatedSize));
    expect(t.renderObject<RenderAnimatedSize>(animated.first).isAnimating, isTrue);
    final targetHeight = t.renderObject<RenderAnimatedSize>(animated.first).child!.size.height;
    final chartState = t.state(find.byType(TimeSeriesChart));
    updateHost(() => tickerActive = false);
    await t.pump();
    expect(t.getSize(find.byKey(const ValueKey('anomaly-expansion:sessions:2026-10-08'))).height, targetHeight);
    expect(t.state(find.byType(TimeSeriesChart)), same(chartState));

    updateHost(() => tickerActive = true);
    await t.pumpAndSettle();
    await t.tap(find.text('Sessions changed'));
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const ValueKey('anomaly-expansion:sessions:2026-10-08'))).height, 0);
    await t.tap(find.text('Sessions changed'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    final reanimated = find.ancestor(of: find.byType(TimeSeriesChart), matching: find.byType(AnimatedSize));
    expect(t.renderObject<RenderAnimatedSize>(reanimated.first).isAnimating, isTrue);
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const ValueKey('anomaly-expansion:sessions:2026-10-08'))).height, targetHeight);
  });
}
