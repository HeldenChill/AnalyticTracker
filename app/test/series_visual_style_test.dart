import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/charts/chart_models.dart';
import 'package:analytic_app/src/widgets/charts/series_visual_style.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palette overflow and reference keep identifiable styles', () {
    const palette = [Colors.blue, Colors.green];
    final first = resolveSeriesVisualStyle(
      palette: palette,
      slot: 0,
      seriesId: 'a',
      outline: Colors.black,
    );
    final repeated = resolveSeriesVisualStyle(
      palette: palette,
      slot: 2,
      seriesId: 'c',
      outline: Colors.black,
    );
    final reference = resolveSeriesVisualStyle(
      palette: palette,
      slot: 0,
      seriesId: 'previous',
      outline: Colors.black,
    );
    expect(first.color, repeated.color);
    expect(first.lineDash, isNull);
    expect(repeated.lineDash, [6, 4]);
    expect(first.rodBorder, BorderSide.none);
    expect(repeated.rodBorder.width, greaterThan(0));
    expect(reference.lineDash, [6, 4]);
  });

  testWidgets('legend and plot read matching resolved styles across themes', (t) async {
    for (final style in AppStyle.values) {
      final theme = buildTheme(style);
      final seriesList = [
        for (var i = 0; i < 5; i++)
          ChartSeries(
            id: 'series-$i',
            label: 'Series $i',
            points: [ChartPoint(0, (i + 1).toDouble(), label: 'day')],
          ),
      ];

      await t.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: TimeSeriesChart(
            unit: 'events',
            series: seriesList,
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 401));

      final lineChart = t.widget<LineChart>(find.byType(LineChart));
      for (var i = 0; i < 5; i++) {
        final sampleFinder = find.byKey(ValueKey('series-sample:series-$i'));
        expect(sampleFinder, findsOneWidget);
        final paintWidget = t.widget<CustomPaint>(sampleFinder);
        final painter = paintWidget.painter as SeriesSamplePainter;
        expect(painter.style.color, lineChart.data.lineBarsData[i].color);
        expect(painter.style.lineDash, lineChart.data.lineBarsData[i].dashArray);
      }
    }
  });

  test('barObservationStyle applies partial styling without mutating base values', () {
    const base = SeriesVisualStyle(
      color: Color(0xFF204080),
      lineDash: [6, 4],
      rodBorder: BorderSide(color: Colors.black, width: 2),
    );
    final complete = barObservationStyle(base, incomplete: false, outline: Colors.red);
    expect(identical(complete, base), isTrue);

    final partial = barObservationStyle(base, incomplete: true, outline: const Color(0xFF112233));
    expect(partial.color.a, closeTo(base.color.a * 0.65, 0.01));
    expect(partial.rodBorder.width, 4);
    expect(partial.rodBorder.color.a, closeTo(1.0 * 0.65, 0.01));
    expect(partial.lineDash, base.lineDash);
    expect(describeSeriesVisualStyle(partial, isBars: true, seriesId: 's1'), 'partial observation');
  });

  testWidgets('partial bar styling preserves exact toY values including zero and negative', (t) async {
    for (final style in AppStyle.values) {
      final theme = buildTheme(style);
      final seriesList = [
        const ChartSeries(
          id: 'a-primary',
          label: 'Primary',
          points: [
            ChartPoint(0, 10, label: 'p1', incomplete: false),
            ChartPoint(1, 0, label: 'p2', incomplete: true),
            ChartPoint(2, -5, label: 'p3', incomplete: true),
          ],
        ),
        const ChartSeries(
          id: 'b-previous',
          label: 'Previous',
          points: [
            ChartPoint(0, 8, label: 'p1', incomplete: false),
            ChartPoint(1, 2, label: 'p2', incomplete: false),
            ChartPoint(2, -3, label: 'p3', incomplete: true),
          ],
        ),
      ];

      await t.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: TimeSeriesChart(
            kind: TimeChartKind.bars,
            unit: 'events',
            series: seriesList,
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 401));

      final barChart = t.widget<BarChart>(find.byType(BarChart));
      // Group 0: complete primary (toY=10), complete previous (toY=8)
      expect(barChart.data.barGroups[0].barRods[0].toY, 10);
      expect(barChart.data.barGroups[0].barRods[0].borderSide.width, isNot(4));
      expect(barChart.data.barGroups[0].barRods[1].toY, 8);
      expect(barChart.data.barGroups[0].barRods[1].borderSide.width, isNot(4));

      // Group 1: partial primary (toY=0), complete previous (toY=2)
      expect(barChart.data.barGroups[1].barRods[0].toY, 0);
      expect(barChart.data.barGroups[1].barRods[0].borderSide.width, 4);
      expect(barChart.data.barGroups[1].barRods[1].toY, 2);
      expect(barChart.data.barGroups[1].barRods[1].borderSide.width, isNot(4));

      // Group 2: partial primary (toY=-5), partial previous (toY=-3)
      expect(barChart.data.barGroups[2].barRods[0].toY, -5);
      expect(barChart.data.barGroups[2].barRods[0].borderSide.width, 4);
      expect(barChart.data.barGroups[2].barRods[1].toY, -3);
      expect(barChart.data.barGroups[2].barRods[1].borderSide.width, 4);

      expect(find.byKey(const ValueKey('partial-bar-legend')), findsOneWidget);
    }
  });
}
