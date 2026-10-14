import 'package:analytic_app/src/pages/overview_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/charts/chart_reveal.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_app/src/widgets/dashboard_chart_panel.dart';
import 'package:analytic_app/src/widgets/kpi_card.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_test_host.dart';

const _kpis = Kpis(
  dau: 125,
  newUsers: 340,
  sessions: 920,
  sessionsPerDau: 2.7,
  playtimeMinPerDau: 14.5,
  uninstalls: 45,
);

const _previousKpis = Kpis(
  dau: 100,
  newUsers: 300,
  sessions: 800,
  sessionsPerDau: 2.5,
  playtimeMinPerDau: 12.0,
  uninstalls: 50,
);

const _daily = [
  DailyMetrics(
      day: '2026-10-01', dau: 10, newUsers: 5, sessions: 25, uninstalls: 2),
  DailyMetrics(
      day: '2026-10-02', dau: 0, newUsers: 0, sessions: 0, uninstalls: 0),
  DailyMetrics(
      day: '2026-10-03', dau: 15, newUsers: 8, sessions: 40, uninstalls: 4),
];

void main() {
  testWidgets(
      'Overview renders 4 DashboardChartPanel with exact keys and kinds',
      (t) async {
    await pumpStudio(
      t,
      const OverviewPage(),
      width: 1440,
      overrides: [
        overviewProvider.overrideWith((ref, f) async => const OverviewData(
              kpis: _kpis,
              previous: _previousKpis,
              daily: _daily,
            )),
      ],
    );

    // Verify 4 stable keys exist
    final dauPanel = find.byKey(const ValueKey('overview-dau-chart'));
    final newUsersPanel =
        find.byKey(const ValueKey('overview-new-users-chart'));
    final sessionsPanel = find.byKey(const ValueKey('overview-sessions-chart'));
    final uninstallsPanel =
        find.byKey(const ValueKey('overview-uninstalls-chart'));

    expect(dauPanel, findsOneWidget);
    expect(newUsersPanel, findsOneWidget);
    expect(sessionsPanel, findsOneWidget);
    expect(uninstallsPanel, findsOneWidget);

    // Verify kinds and exact daily data passed
    final dauWidget = t.widget<DashboardChartPanel>(dauPanel);
    expect(dauWidget.kind, TimeChartKind.area);
    expect(dauWidget.series.points.map((p) => p.value).toList(),
        [10.0, 0.0, 15.0]);

    final newUsersWidget = t.widget<DashboardChartPanel>(newUsersPanel);
    expect(newUsersWidget.kind, TimeChartKind.bars);
    expect(newUsersWidget.series.points.map((p) => p.value).toList(),
        [5.0, 0.0, 8.0]);

    final sessionsWidget = t.widget<DashboardChartPanel>(sessionsPanel);
    expect(sessionsWidget.kind, TimeChartKind.area);
    expect(sessionsWidget.series.points.map((p) => p.value).toList(),
        [25.0, 0.0, 40.0]);

    final uninstallsWidget = t.widget<DashboardChartPanel>(uninstallsPanel);
    expect(uninstallsWidget.kind, TimeChartKind.bars);
    expect(uninstallsWidget.series.points.map((p) => p.value).toList(),
        [2.0, 0.0, 4.0]);

    // Verify KPI semantics retained and distinct from daily points
    expect(find.text('DAU (avg)'), findsOneWidget);
    expect(find.text('125.0'), findsOneWidget);
    expect(find.text('340'), findsOneWidget);
    expect(find.text('920'), findsOneWidget);
    expect(find.text('2.7'), findsOneWidget);
    expect(find.text('14.5 min'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
  });

  testWidgets(
      'KPI cards responsive layout at 1440, 1024, 720, and 320 with text scale 1.5 and bold',
      (t) async {
    final overrides = [
      overviewProvider.overrideWith((ref, f) async => const OverviewData(
            kpis: _kpis,
            previous: _previousKpis,
            daily: _daily,
          )),
    ];

    // Width 1440: all 6 cards on one row (same top)
    await pumpStudio(t, const OverviewPage(),
        width: 1440, overrides: overrides);
    var cards = t.widgetList<KpiCard>(find.byType(KpiCard)).toList();
    expect(cards.length, 6);
    var tops = [for (final c in cards) t.getTopLeft(find.byWidget(c)).dy];
    expect(tops.toSet().length, 1,
        reason: 'At 1440, all 6 cards share the exact same top position');

    // Width 850 (or 1024 shell with navigation rail): 3 + 3
    await pumpStudio(t, const OverviewPage(), width: 850, overrides: overrides);
    cards = t.widgetList<KpiCard>(find.byType(KpiCard)).toList();
    tops = [for (final c in cards) t.getTopLeft(find.byWidget(c)).dy];
    expect(tops.take(3).toSet().length, 1, reason: 'First 3 cards share top');
    expect(tops.skip(3).take(3).toSet().length, 1,
        reason: 'Last 3 cards share top');
    expect(tops[0], lessThan(tops[3]));

    // Width 320 at textScale 1.5 and bold text: no overflow and no assertion
    await pumpStudio(
      t,
      const OverviewPage(),
      width: 320,
      textScale: 1.5,
      bold: true,
      overrides: overrides,
    );
    expect(find.byType(KpiCard), findsNWidgets(6));
    expect(t.takeException(), isNull);
  });

  testWidgets('Overview motion samples DAU clip and New users bar geometry',
      (t) async {
    await pumpStudio(
      t,
      const OverviewPage(),
      width: 1440,
      overrides: [
        overviewProvider.overrideWith((ref, f) async => const OverviewData(
              kpis: _kpis,
              previous: _previousKpis,
              daily: _daily,
            )),
      ],
      settle: false,
    );

    // Initial frame
    final clipFinder = find.descendant(
      of: find.byKey(const ValueKey('overview-dau-chart')),
      matching: find.byWidgetPredicate(
        (w) => w is ClipRect && w.clipper is ChartRevealClip,
      ),
    );
    expect(clipFinder, findsOneWidget);
    final clip0 = t.widget<ClipRect>(clipFinder).clipper as ChartRevealClip;
    expect(clip0.progress, closeTo(0, 0.05));
    final newUsersBars = find.descendant(
      of: find.byKey(const ValueKey('overview-new-users-chart')),
      matching: find.byType(BarChart),
    );
    BarChartData barData() => t.widget<BarChart>(newUsersBars).data;
    final fullY = barData().maxY;
    expect(barData().barGroups.first.barRods.first.toY, closeTo(0, .001));

    // Mid animation (200ms)
    await t.pump(const Duration(milliseconds: 200));
    final clipMid = t.widget<ClipRect>(clipFinder).clipper as ChartRevealClip;
    expect(clipMid.progress, greaterThan(0));
    expect(clipMid.progress, lessThan(1));
    expect(barData().barGroups.first.barRods.first.toY, greaterThan(0));
    expect(barData().barGroups.first.barRods.first.toY, lessThan(5));
    expect(barData().maxY, fullY);

    // Settled (450ms)
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-dau-chart')),
          matching: find.byWidgetPredicate(
            (w) => w is ClipRect && w.clipper is ChartRevealClip,
          ),
        ),
        findsNothing);

    // Bar chart has finished rendering rods
    final barChartFinder = find.descendant(
      of: find.byKey(const ValueKey('overview-new-users-chart')),
      matching: find.byType(BarChart),
    );
    expect(barChartFinder, findsOneWidget);
    expect(barData().barGroups.first.barRods.first.toY, 5);
    expect(barData().maxY, fullY);
  });

  testWidgets(
      'Overview empty daily preserves No data banner and empty chart state',
      (t) async {
    await pumpStudio(
      t,
      const OverviewPage(),
      width: 1440,
      overrides: [
        overviewProvider.overrideWith((ref, f) async => const OverviewData(
              kpis: Kpis(
                  dau: 0,
                  newUsers: 0,
                  sessions: 0,
                  sessionsPerDau: null,
                  playtimeMinPerDau: null,
                  uninstalls: 0),
              previous: null,
              daily: [
                DailyMetrics(
                    day: '2026-10-01',
                    dau: 0,
                    newUsers: 0,
                    sessions: 0,
                    uninstalls: 0)
              ],
            )),
      ],
    );

    expect(find.text('No data in this range'), findsOneWidget);
    expect(find.text('— min'), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-dau-chart')), findsOneWidget);
  });
}
