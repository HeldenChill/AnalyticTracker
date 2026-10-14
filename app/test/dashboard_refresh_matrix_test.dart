import 'package:analytic_app/src/pages/funnel_page.dart';
import 'package:analytic_app/src/pages/overview_page.dart';
import 'package:analytic_app/src/pages/retention_page.dart';
import 'package:analytic_app/src/pages/progression_page.dart';
import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_app/src/widgets/dashboard_chart_panel.dart';
import 'package:analytic_app/src/widgets/studio_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_matrix_fixtures.dart';
import 'support/studio_test_host.dart';
import 'support/studio_text_assertions.dart';

Finder _vertical(Type page) => find.descendant(
    of: find.byType(page),
    matching: find.byWidgetPredicate((w) =>
        w is Scrollable &&
        axisDirectionToAxis(w.axisDirection) == Axis.vertical));

Future<void> _inspectData(
    WidgetTester t, Type page, String key, List<String> expected,
    {List<String> numbers = const []}) async {
  final panel = find.byKey(ValueKey(key));
  await t.scrollUntilVisible(panel, 180,
      scrollable: _vertical(page), maxScrolls: 30);
  await t.pumpAndSettle();
  final heading = t.widget<DashboardChartPanel>(panel).title;
  expectCompleteWrappedText(
      t, find.descendant(of: panel, matching: find.text(heading)));
  final button = find.descendant(of: panel, matching: find.text('View data'));
  await t.scrollUntilVisible(button, 180,
      scrollable: _vertical(page), maxScrolls: 30);
  await t.pumpAndSettle();
  expect(t.getRect(_vertical(page)).contains(t.getCenter(button)), isTrue,
      reason:
          '$key button ${t.getRect(button)} viewport ${t.getRect(_vertical(page))}');
  await t.tap(button);
  await t.pumpAndSettle();
  final table = find.descendant(of: panel, matching: find.byType(StudioTable));
  expect(table, findsOneWidget);
  for (final value in expected) {
    final cell = find.descendant(of: table, matching: find.text(value));
    expect(cell, findsWidgets);
    expectCompleteWrappedText(t, cell.first);
  }
  final horizontal = find.descendant(
      of: table,
      matching: find.byWidgetPredicate((w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.horizontal));
  final scroll = t.state<ScrollableState>(horizontal);
  scroll.position.jumpTo(scroll.position.maxScrollExtent);
  await t.pumpAndSettle();
  final lastColumn = find.descendant(of: table, matching: find.text('Value'));
  expect(t.getRect(horizontal).overlaps(t.getRect(lastColumn)), isTrue);
  for (final value in numbers) {
    expectCompleteSingleLine(
        t, find.descendant(of: table, matching: find.text(value)).first);
  }
  await t.tap(button);
  await t.pumpAndSettle();
  expect(table, findsNothing);
}

Future<void> _inspectStageEnd(WidgetTester t) async {
  final details = find.byKey(const ValueKey('progression-stage-details'));
  final heading =
      find.descendant(of: details, matching: find.text('Stage details'));
  await t.scrollUntilVisible(heading, 180,
      scrollable: _vertical(ProgressionPage), maxScrolls: 30);
  await t.pumpAndSettle();
  final horizontal = find.descendant(
      of: details,
      matching: find.byWidgetPredicate((w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.horizontal));
  final state = t.state<ScrollableState>(horizontal);
  state.position.jumpTo(state.position.maxScrollExtent);
  await t.pumpAndSettle();
  final label = find.descendant(of: details, matching: find.text('Drop-off'));
  expect(t.getRect(horizontal).overlaps(t.getRect(label)), isTrue);
  expectCompleteWrappedText(t, label);
  final value = find.descendant(of: details, matching: find.text('—'));
  expect(t.getRect(horizontal).overlaps(t.getRect(value)), isTrue);
  expectCompleteSingleLine(t, value);
}

void main() {
  group('Dashboard Refresh Matrix - 4 styles, widths & text scales', () {
    for (final style in AppStyle.values) {
      for (final width in [720.0, 1024.0, 1440.0]) {
        for (final scale in [1.0, 1.5]) {
          testWidgets('Matrix ${style.name} width $width scale $scale',
              (t) async {
            await pumpStudio(
              t,
              const AppShell(),
              width: width,
              textScale: scale,
              style: style,
              overrides: studioMatrixOverrides(withFunnels: true),
            );

            // Filter bar exists with stable keys
            expect(find.byKey(const ValueKey('filter-date-range')),
                findsOneWidget);
            expect(
                find.byKey(const ValueKey('filter-platform')), findsOneWidget);
            expect(
                find.byKey(const ValueKey('filter-version')), findsOneWidget);
            expect(find.byKey(const ValueKey('filter-test-devices')),
                findsOneWidget);
            expect(
                find.byKey(const ValueKey('refresh-button')), findsOneWidget);

            // Overview page charts exist with exact kinds
            expect(find.byKey(const ValueKey('overview-dau-chart')),
                findsOneWidget);
            expect(find.byKey(const ValueKey('overview-new-users-chart')),
                findsOneWidget);
            expect(find.byKey(const ValueKey('overview-sessions-chart')),
                findsOneWidget);
            expect(find.byKey(const ValueKey('overview-uninstalls-chart')),
                findsOneWidget);

            final dauWidget = t.widget<DashboardChartPanel>(
                find.byKey(const ValueKey('overview-dau-chart')));
            expect(dauWidget.kind, TimeChartKind.area);

            final newUsersWidget = t.widget<DashboardChartPanel>(
                find.byKey(const ValueKey('overview-new-users-chart')));
            expect(newUsersWidget.kind, TimeChartKind.bars);
            await _inspectData(
                t, OverviewPage, 'overview-dau-chart', ['2026-10-01', '10'],
                numbers: ['10']);
            await _inspectData(t, OverviewPage, 'overview-new-users-chart',
                ['2026-10-01', '2'],
                numbers: ['2']);

            final container =
                ProviderScope.containerOf(t.element(find.byType(AppShell)));

            // Navigate to Retention
            container.read(selectedPageProvider.notifier).state =
                AppPage.retention;
            await t.pumpAndSettle();

            expect(find.byKey(const ValueKey('retention-d1')), findsOneWidget);
            expect(find.byKey(const ValueKey('retention-d7')), findsOneWidget);
            expect(find.byKey(const ValueKey('retention-d14')), findsOneWidget);
            expect(
                find.byKey(const ValueKey('retention-curve')), findsOneWidget);
            await _inspectData(t, RetentionPage, 'retention-curve',
                ['D1', 'D7', '50.0%', '30.0%', 'Unavailable'],
                numbers: ['50.0%', '30.0%']);

            // Navigate to Progression
            container.read(selectedPageProvider.notifier).state =
                AppPage.progression;
            await t.pumpAndSettle();

            expect(find.byKey(const ValueKey('progression-reach-chart')),
                findsOneWidget);
            expect(find.byKey(const ValueKey('progression-win-rate-chart')),
                findsOneWidget);
            expect(find.byKey(const ValueKey('progression-drop-off-chart')),
                findsOneWidget);
            await _inspectData(t, ProgressionPage, 'progression-reach-chart',
                ['Stage 1', '10'],
                numbers: ['10']);
            await _inspectData(t, ProgressionPage, 'progression-win-rate-chart',
                ['Stage 1', '50.0%'],
                numbers: ['50.0%']);
            await _inspectData(t, ProgressionPage, 'progression-drop-off-chart',
                ['Stage 1', 'Unavailable']);
            await _inspectStageEnd(t);

            expect(t.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('Matrix focused 320 width with 1.5 text scale and bold',
        (t) async {
      await pumpStudio(
        t,
        const AppShell(),
        width: 320,
        height: 1200,
        textScale: 1.5,
        bold: true,
        style: AppStyle.tremor,
        overrides: studioMatrixOverrides(withFunnels: true),
      );

      // Verify filter bar controls wrap without throwing
      expect(find.byKey(const ValueKey('filter-date-range')), findsOneWidget);
      expect(find.byKey(const ValueKey('refresh-button')), findsOneWidget);

      final dauChartFinder = find.byKey(const ValueKey('overview-dau-chart'));
      await t.scrollUntilVisible(dauChartFinder, 200);
      expect(dauChartFinder, findsOneWidget);
      await _inspectData(
          t, OverviewPage, 'overview-dau-chart', ['2026-10-01', '10'],
          numbers: ['10']);
      final c = ProviderScope.containerOf(t.element(find.byType(AppShell)));
      c.read(selectedPageProvider.notifier).state = AppPage.retention;
      await t.pumpAndSettle();
      await _inspectData(t, RetentionPage, 'retention-curve',
          ['D1', 'D7', '50.0%', 'Unavailable'],
          numbers: ['50.0%']);
      c.read(selectedPageProvider.notifier).state = AppPage.progression;
      await t.pumpAndSettle();
      await _inspectData(
          t, ProgressionPage, 'progression-reach-chart', ['Stage 1', '10'],
          numbers: ['10']);
      await _inspectStageEnd(t);

      expect(t.takeException(), isNull);
    });
  });

  group('Dashboard Refresh - Navigation lifecycle & filter stability', () {
    testWidgets('Full shell settled navigation preserves selected platform',
        (t) async {
      await pumpStudio(
        t,
        const AppShell(),
        width: 1440,
        overrides: studioMatrixOverrides(withFunnels: true),
      );

      // Change platform filter to ANDROID
      await t.tap(find.byKey(const ValueKey('filter-platform')));
      await t.pumpAndSettle();
      await t.tap(find.text('ANDROID').last);
      await t.pumpAndSettle();

      // Navigate Overview -> Retention -> Progression -> Funnels -> Overview via sidebar
      await t.tap(find.text('Retention'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('retention-curve')), findsOneWidget);

      await t.tap(find.text('Progression'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('progression-reach-chart')),
          findsOneWidget);

      await t.tap(find.text('Funnels'));
      await t.pumpAndSettle();
      expect(find.byType(FunnelPage), findsOneWidget);

      await t.tap(find.text('Overview'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('overview-dau-chart')), findsOneWidget);

      // Platform filter remains selected as ANDROID
      expect(find.text('ANDROID'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
