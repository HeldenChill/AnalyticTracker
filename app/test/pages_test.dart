import 'package:analytic_app/src/pages/overview_page.dart';
import 'package:analytic_app/src/pages/progression_page.dart';
import 'package:analytic_app/src/pages/retention_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester t, List<Override> overrides, Widget page) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: page)),
  ));
  await t.pumpAndSettle();
}

const kpis = Kpis(dau: 37, newUsers: 214, sessions: 511, sessionsPerDau: 1.4, playtimeMinPerDau: 6.2, uninstalls: 128);

void main() {
  testWidgets('Overview shows KPI cards and deltas', (t) async {
    await pump(t, [
      overviewProvider.overrideWith((ref, f) async => const OverviewData(
            kpis: kpis,
            previous: Kpis(dau: 33, newUsers: 214, sessions: 500, sessionsPerDau: 1.4, playtimeMinPerDau: 6.0, uninstalls: 100),
            // Daily values deliberately differ from KPI values so chart axis labels
            // can never collide with the KPI texts asserted below.
            daily: [
              DailyMetrics(day: '2026-10-01', dau: 5, newUsers: 3, sessions: 7, uninstalls: 2),
              DailyMetrics(day: '2026-10-02', dau: 6, newUsers: 4, sessions: 8, uninstalls: 1),
            ],
          )),
    ], const OverviewPage());
    expect(find.text('DAU (avg)'), findsOneWidget);
    expect(find.text('37.0'), findsOneWidget);
    expect(find.text('214'), findsOneWidget);
    expect(find.text('6.2 min'), findsOneWidget);
    expect(find.text('▲ 12% vs prev'), findsOneWidget);
    expect(find.text('▲ 28% vs prev'), findsOneWidget);
  });

  testWidgets('Overview with no data shows banner', (t) async {
    await pump(t, [
      overviewProvider.overrideWith((ref, f) async => const OverviewData(
            kpis: Kpis(dau: 0, newUsers: 0, sessions: 0, sessionsPerDau: null, playtimeMinPerDau: null, uninstalls: 0),
            previous: null,
            daily: [DailyMetrics(day: '2026-10-01', dau: 0, newUsers: 0, sessions: 0, uninstalls: 0)],
          )),
    ], const OverviewPage());
    expect(find.text('No data in this range'), findsOneWidget);
    expect(find.text('— min'), findsOneWidget);
  });

  testWidgets('Retention empty and summary', (t) async {
    await pump(t, [
      retentionProvider.overrideWith((ref, f) async =>
          const RetentionData(offsets: [1, 3, 7, 14, 30], lastDataDay: null, cohorts: [], average: [null, null, null, null, null])),
    ], const RetentionPage());
    expect(find.text('No installs (first_open) in this range'), findsOneWidget);
  });

  testWidgets('Retention summary line', (t) async {
    await pump(t, [
      retentionProvider.overrideWith((ref, f) async => const RetentionData(
            offsets: [1, 3, 7, 14, 30],
            lastDataDay: '2026-10-08',
            cohorts: [RetentionCohort(day: '2026-10-01', size: 4, retained: [1, 1, 0, null, null])],
            average: [0.25, 0.25, 0.0, null, null],
          )),
    ], const RetentionPage());
    expect(find.text('D1 25% · D7 0%'), findsOneWidget);
  });

  testWidgets('Progression empty state', (t) async {
    await pump(t, [
      progressionProvider.overrideWith((ref, f) async => const ProgressionData(stages: [])),
    ], const ProgressionPage());
    expect(find.textContaining('No stage events yet'), findsOneWidget);
  });

  testWidgets('Progression shows table and players bars', (t) async {
    await pump(t, [
      progressionProvider.overrideWith((ref, f) async => const ProgressionData(stages: [
            StageRow(stage: 1, players: 10, starts: 12, completes: 8, fails: 4, winRate: 2 / 3, attemptsPerClear: 1.2, dropOff: 0.5),
            StageRow(stage: 2, players: 5, starts: 5, completes: 5, fails: 0, winRate: 1.0, attemptsPerClear: 1.0, dropOff: null),
          ])),
    ], const ProgressionPage());
    expect(find.text('Players reaching each stage'), findsOneWidget);
    expect(find.text('Stage 1'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
  });
}
