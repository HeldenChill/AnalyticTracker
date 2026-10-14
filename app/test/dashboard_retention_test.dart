import 'package:analytic_app/src/pages/retention_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_app/src/widgets/dashboard_chart_panel.dart';
import 'package:analytic_app/src/widgets/retention_table.dart';
import 'package:analytic_app/src/widgets/studio_layout.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/line_chart/line_chart_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_test_host.dart';

const _offsets = [1, 3, 7, 14, 30];

const _matureCohort = RetentionCohort(
  day: '2026-09-01',
  size: 100,
  retained: [40, 30, 0, null, null],
);

const _immatureCohort = RetentionCohort(
  day: '2026-10-10',
  size: 50,
  retained: [20, null, null, null, null],
);

const _standardRetention = RetentionData(
  offsets: _offsets,
  lastDataDay: '2026-10-12',
  cohorts: [_matureCohort, _immatureCohort],
  average: [0.4, 0.3, 0.0, null, null],
);

void main() {
  testWidgets(
      'Retention renders summaries, retention curve, and cohort table with exact keys',
      (t) async {
    await pumpStudio(
      t,
      const RetentionPage(),
      width: 1440,
      overrides: [
        retentionProvider.overrideWith((ref, f) async => _standardRetention),
      ],
    );

    // Verify stable keys
    final d1Finder = find.byKey(const ValueKey('retention-d1'));
    final d7Finder = find.byKey(const ValueKey('retention-d7'));
    final d14Finder = find.byKey(const ValueKey('retention-d14'));
    final curveFinder = find.byKey(const ValueKey('retention-curve'));
    final cohortsFinder = find.byKey(const ValueKey('retention-cohorts'));

    expect(d1Finder, findsOneWidget);
    expect(d7Finder, findsOneWidget);
    expect(d14Finder, findsOneWidget);
    expect(curveFinder, findsOneWidget);
    expect(cohortsFinder, findsOneWidget);

    // Label-scoped summary checks
    final d1Metric = t.widget<StudioMetric>(d1Finder);
    expect(d1Metric.value, '40.0%');
    expect(d1Metric.title, 'Day 1 retention');

    final d7Metric = t.widget<StudioMetric>(d7Finder);
    expect(d7Metric.value, '0.0%');
    expect(d7Metric.title, 'Day 7 retention');

    final d14Metric = t.widget<StudioMetric>(d14Finder);
    expect(d14Metric.value, '—');
    expect(d14Metric.title, 'Day 14 retention');

    // Explanation text with lastDataDay
    expect(
        find.textContaining(
            'Only observable cohort days are included; unavailable days are not zero.'),
        findsOneWidget);
    expect(find.textContaining('Data through 2026-10-12'), findsOneWidget);

    // Curve panel configuration
    final curvePanel = t.widget<DashboardChartPanel>(curveFinder);
    expect(curvePanel.kind, TimeChartKind.line);
    expect(curvePanel.percentage, isTrue);
    expect(
        curvePanel.series.points.map((p) => p.x).toList(), [1, 3, 7, 14, 30]);
    expect(curvePanel.series.points.map((p) => p.value).toList(),
        [0.4, 0.3, 0.0, null, null]);

    // Cohort table present
    expect(
        find.descendant(
            of: cohortsFinder, matching: find.byType(RetentionTable)),
        findsOneWidget);
    expect(find.text('Blank cells are not yet observable.'), findsOneWidget);
  });

  testWidgets(
      'Retention curve x spacing preserves numerical interval ratio (7-3)/(3-1) = 2',
      (t) async {
    await pumpStudio(
      t,
      const RetentionPage(),
      width: 1440,
      overrides: [
        retentionProvider.overrideWith((ref, f) async => _standardRetention),
      ],
      reducedMotion: true,
    );

    final lineChartWidget = t.widget<LineChart>(find.descendant(
      of: find.byKey(const ValueKey('retention-curve')),
      matching: find.byType(LineChart),
    ));

    final spots = lineChartWidget.data.lineBarsData.first.spots;
    expect(spots.length, 3); // D1, D3, D7 (D14, D30 are null)
    expect(spots[0].x, 1.0);
    expect(spots[1].x, 3.0);
    expect(spots[2].x, 7.0);

    final ratio = (spots[2].x - spots[1].x) / (spots[1].x - spots[0].x);
    expect(ratio, closeTo(2.0, 0.001));
    final leaf = find.descendant(
      of: find.byKey(const ValueKey('retention-curve')),
      matching: find.byType(LineChartLeaf),
    );
    final renderer = t.renderObject<RenderLineChart>(leaf);
    double pixel(double x) =>
        renderer.painter.getPixelX(x, renderer.size, renderer.paintHolder);
    expect((pixel(7) - pixel(3)) / (pixel(3) - pixel(1)), closeTo(2, .001));
    final label = find.descendant(
      of: find.byKey(const ValueKey('retention-curve')),
      matching: find.byKey(const ValueKey('chart-x-tick:3.0')),
    );
    expect(t.getRect(label).center.dx,
        closeTo(t.getRect(leaf).left + pixel(3), .5));
  });

  testWidgets(
      'Retention handles nonmonotonic curve [.4, .5, .3] without forcing decreasing line',
      (t) async {
    const nonmonotonic = RetentionData(
      offsets: [1, 3, 7],
      lastDataDay: null,
      cohorts: [
        RetentionCohort(
          day: '2026-09-01',
          size: 100,
          retained: [40, 50, 30],
        ),
      ],
      average: [0.4, 0.5, 0.3],
    );

    await pumpStudio(
      t,
      const RetentionPage(),
      width: 1440,
      overrides: [
        retentionProvider.overrideWith((ref, f) async => nonmonotonic),
      ],
      reducedMotion: true,
    );

    final curvePanel = t.widget<DashboardChartPanel>(
        find.byKey(const ValueKey('retention-curve')));
    expect(
        curvePanel.series.points.map((p) => p.value).toList(), [0.4, 0.5, 0.3]);
  });

  testWidgets('Retention empty cohorts shows empty state with visible heading',
      (t) async {
    const emptyData = RetentionData(
      offsets: [1, 3, 7, 14, 30],
      lastDataDay: null,
      cohorts: [],
      average: [null, null, null, null, null],
    );

    await pumpStudio(
      t,
      const RetentionPage(),
      width: 1440,
      overrides: [
        retentionProvider.overrideWith((ref, f) async => emptyData),
      ],
    );

    expect(find.text('Retention'), findsOneWidget);
    expect(find.text('No installs (first_open) in this range'), findsOneWidget);
  });
}
