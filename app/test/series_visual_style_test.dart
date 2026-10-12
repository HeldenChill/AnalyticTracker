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
}
