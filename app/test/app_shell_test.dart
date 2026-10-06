import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const emptyKpis = Kpis(dau: 0, newUsers: 0, sessions: 0, sessionsPerDau: null, playtimeMinPerDau: null, uninstalls: 0);

void main() {
  late List<Filters> overviewCalls;
  late int daysCalls;

  Future<void> pumpShell(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    overviewCalls = [];
    daysCalls = 0;
    await t.pumpWidget(ProviderScope(
      overrides: [
        daysProvider.overrideWith((ref) async {
          daysCalls++;
          return const <DayStat>[];
        }),
        eventNamesProvider.overrideWith((ref) async => const <String>[]),
        filterOptionsProvider.overrideWith(
            (ref) async => const FilterOptions(platforms: ['ANDROID', 'IOS'], versions: ['1.0.0'])),
        overviewProvider.overrideWith((ref, f) async {
          overviewCalls.add(f);
          return OverviewData(kpis: emptyKpis, previous: null, daily: [
            for (final d in daysBetween(f.from, f.to))
              DailyMetrics(day: d, dau: 0, newUsers: 0, sessions: 0, uninstalls: 0),
          ]);
        }),
        retentionProvider.overrideWith((ref, f) async =>
            const RetentionData(offsets: [1, 3, 7, 14, 30], lastDataDay: null, cohorts: [], average: [null, null, null, null, null])),
        progressionProvider.overrideWith((ref, f) async => const ProgressionData(stages: [])),
        countsProvider.overrideWith((ref, q) async => const <EventCount>[]),
      ],
      child: const MaterialApp(home: AppShell()),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('sidebar navigates between pages', (t) async {
    await pumpShell(t);
    expect(find.text('DAU (avg)'), findsOneWidget);
    for (final label in ['Overview', 'Retention', 'Progression', 'EXPLORE', 'Events', 'Parameters', 'Funnel', 'Data health', 'Settings']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await t.tap(find.text('Retention'));
    await t.pumpAndSettle();
    expect(find.text('No installs (first_open) in this range'), findsOneWidget);
    await t.tap(find.text('Progression'));
    await t.pumpAndSettle();
    expect(find.textContaining('No stage events yet'), findsOneWidget);
  });

  testWidgets('preset change refetches overview', (t) async {
    await pumpShell(t);
    await t.tap(find.byTooltip('Date range'));
    await t.pumpAndSettle();
    await t.tap(find.text('Last 7 days').last);
    await t.pumpAndSettle();
    final expected = defaultFilters(DateTime.now(), days: 7);
    expect(overviewCalls.last.from, expected.from);
    expect(overviewCalls.last.to, expected.to);
  });

  testWidgets('platform filter refetches with platform', (t) async {
    await pumpShell(t);
    await t.tap(find.text('Platform: All'));
    await t.pumpAndSettle();
    await t.tap(find.text('IOS').last);
    await t.pumpAndSettle();
    expect(overviewCalls.last.platform, 'IOS');
  });

  testWidgets('refresh refetches and confirms', (t) async {
    await pumpShell(t);
    final before = daysCalls;
    await t.tap(find.byTooltip('Refresh'));
    await t.pumpAndSettle();
    expect(daysCalls, greaterThan(before));
    expect(find.text('Refreshed'), findsOneWidget);
  });
}
