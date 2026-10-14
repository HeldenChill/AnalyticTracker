import 'package:analytic_app/src/widgets/charts/chart_frame.dart';
import 'package:analytic_app/src/widgets/charts/chart_models.dart';
import 'package:analytic_app/src/widgets/charts/chart_reveal.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_app/src/widgets/dashboard_chart_panel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_test_host.dart';

void main() {
  testWidgets('exact data distinguishes unavailable from measured zero', (t) async {
    await pumpStudio(
      t,
      const DashboardChartPanel(
        title: 'Return rate',
        subtitle: 'Days since install',
        unit: 'retained players (%)',
        percentage: true,
        series: ChartSeries(
          id: 'primary',
          label: 'Weighted retention',
          points: [
            ChartPoint(1, .4, label: 'D1'),
            ChartPoint(3, null, label: 'D3'),
            ChartPoint(7, 0, label: 'D7'),
          ],
        ),
      ),
      width: 320,
      textScale: 1.5,
      reducedMotion: true,
    );
    await t.tap(find.text('View data'));
    await t.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('40.0%'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('ChartFrame compactHeader:false keeps default heading and compactHeader:true styles compactly', (t) async {
    // Default compactHeader: false
    await pumpStudio(
      t,
      const ChartFrame(
        title: 'Default heading',
        subtitle: 'Default subtitle',
        unit: 'count',
        child: SizedBox(height: 200),
      ),
    );
    expect(find.text('Default heading'), findsOneWidget);

    // Compact header at 320 width, 1.5 scale, bold text
    await pumpStudio(
      t,
      const ChartFrame(
        compactHeader: true,
        title: 'Compact heading title that wraps cleanly',
        subtitle: 'Compact subtitle text',
        unit: 'players (%)',
        child: SizedBox(height: 200),
      ),
      width: 320,
      textScale: 1.5,
      bold: true,
    );
    expect(find.text('Compact heading title that wraps cleanly'), findsOneWidget);
    expect(find.text('Compact subtitle text'), findsOneWidget);
    expect(find.text('players (%)'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('panel grows real columns while full y domain stays fixed', (t) async {
    await pumpStudio(
      t,
      const DashboardChartPanel(
        title: 'Players',
        subtitle: 'Stage order',
        unit: 'players',
        kind: TimeChartKind.bars,
        series: ChartSeries(
          id: 'primary',
          label: 'Players',
          points: [
            ChartPoint(1, 10, label: 'Stage 1'),
            ChartPoint(3, 20, label: 'Stage 3'),
          ],
        ),
      ),
      textScale: 1,
      settle: false,
    );
    BarChartData data() => t.widget<BarChart>(find.byType(BarChart)).data;
    final maxY = data().maxY;
    expect(data().barGroups.last.barRods.single.toY, closeTo(0, .001));
    await t.pump(const Duration(milliseconds: 200));
    final middle = data().barGroups.last.barRods.single.toY;
    expect(middle, greaterThan(0));
    expect(middle, lessThan(20));
    expect(data().maxY, maxY);
    await t.pump(const Duration(milliseconds: 250));
    expect(data().barGroups.last.barRods.single.toY, 20);
    expect(data().maxY, maxY);
  });

  testWidgets('panel reveals line plot without shrinking axes', (t) async {
    await pumpStudio(
      t,
      const DashboardChartPanel(
        title: 'Return',
        subtitle: 'Weighted average',
        unit: 'retained players (%)',
        percentage: true,
        series: ChartSeries(
          id: 'primary',
          label: 'Weighted retention',
          points: [
            ChartPoint(1, .4, label: 'D1'),
            ChartPoint(7, .2, label: 'D7'),
          ],
        ),
      ),
      textScale: 1,
      settle: false,
    );
    final clips = find.byWidgetPredicate(
      (w) => w is ClipRect && w.clipper is ChartRevealClip,
    );
    ChartRevealClip clip() => t.widget<ClipRect>(clips).clipper! as ChartRevealClip;
    final initial = clip();
    expect(initial.progress, closeTo(0, .001));
    await t.pump(const Duration(milliseconds: 200));
    expect(clip().progress, greaterThan(0));
    expect(clip().progress, lessThan(1));
    expect(clip().plot, initial.plot);
    await t.pump(const Duration(milliseconds: 250));
    expect(clips, findsNothing);
    final finalChart = t.widget<LineChart>(find.byType(LineChart));
    expect(finalChart.data.minY, 0);
    expect(finalChart.data.maxY, 1);
  });

  testWidgets('panel with custom valueFormatter formats exact data and points', (t) async {
    await pumpStudio(
      t,
      DashboardChartPanel(
        title: 'Drop off',
        subtitle: 'Difficulty',
        unit: 'drop-off (%)',
        percentage: false,
        valueFormatter: (v) => '${(v * 100).toStringAsFixed(1)}%',
        series: const ChartSeries(
          id: 'primary',
          label: 'Drop-off',
          points: [
            ChartPoint(1, -.2, label: 'Stage 1'),
            ChartPoint(2, null, label: 'Stage 2'),
          ],
        ),
      ),
      reducedMotion: true,
    );
    await t.tap(find.text('View data'));
    await t.pumpAndSettle();
    expect(find.text('-20.0%'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
  });
}
