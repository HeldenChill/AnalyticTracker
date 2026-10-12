import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/charts/chart_frame.dart';
import 'package:analytic_app/src/widgets/charts/chart_models.dart';
import 'package:analytic_app/src/widgets/charts/chart_motion.dart';
import 'package:analytic_app/src/widgets/charts/diverging_bar_chart.dart';
import 'package:analytic_app/src/widgets/charts/ranked_bar_chart.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_app/src/widgets/format.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_test_host.dart';
import 'support/studio_text_assertions.dart';

Future<void> pumpRepairChart(WidgetTester t, Widget child, {
  double width = 320,
  double scale = 1,
  bool bold = false,
  bool reduced = false,
  bool active = true,
  AppStyle style = AppStyle.tremor,
}) async {
  await t.pumpWidget(MaterialApp(
    theme: buildTheme(style),
    themeAnimationDuration: Duration.zero,
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(scale),
        boldText: bold,
        disableAnimations: reduced,
      ),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TickerMode(
              enabled: active,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('actual series legend wraps full long label', (t) async {
    final label = List.filled(20, 'long series name').join(' ');
    await pumpRepairChart(
      t,
      TimeSeriesChart(
        unit: 'events',
        series: [
          ChartSeries(
            id: 'reference',
            label: label,
            points: const [ChartPoint(0, 1, label: 'day')],
          ),
        ],
      ),
      scale: 1.5,
      bold: true,
      reduced: true,
    );
    expect(t.takeException(), isNull);
    expectCompleteWrappedText(t, find.text(label));
    final paragraph = t.getRect(find.text(label));
    expect(paragraph.right, lessThanOrEqualTo(320.5));
  });

  testWidgets('fraction domains are fixed for every time chart kind', (t) async {
    for (final kind in TimeChartKind.values) {
      for (final value in [0.0, .3, 1.0]) {
        await pumpRepairChart(
          t,
          TimeSeriesChart(
            kind: kind,
            unit: '%',
            percentage: true,
            series: [
              ChartSeries(
                id: 'primary',
                label: 'Conversion',
                points: [ChartPoint(0, value, label: 'day')],
              ),
            ],
          ),
          reduced: true,
        );
        final data = kind == TimeChartKind.bars
            ? t.widget<BarChart>(find.byType(BarChart)).data
            : t.widget<LineChart>(find.byType(LineChart)).data;
        if (data is BarChartData) {
          expect(data.minY, 0);
          expect(data.maxY, 1);
        }
        if (data is LineChartData) {
          expect(data.minY, 0);
          expect(data.maxY, 1);
        }
      }
    }
  });

  testWidgets('invalid percentage values trigger finite chart axis fallback', (t) async {
    for (final bad in [-0.01, 1.01, double.nan, double.infinity]) {
      await pumpRepairChart(
        t,
        TimeSeriesChart(
          unit: '%',
          percentage: true,
          series: [
            ChartSeries(
              id: 'primary',
              label: 'Conversion',
              points: [ChartPoint(0, bad, label: 'day')],
            ),
          ],
        ),
        reduced: true,
      );
      expect(find.text('These values cannot be displayed on a finite chart axis.'), findsOneWidget);
    }
  });

  testWidgets('responsive chart preserves real zero and missing gaps', (t) async {
    await pumpStudio(
      t,
      const ChartFrame(
        title: 'Actual counts',
        unit: 'events',
        child: TimeSeriesChart(
          unit: 'events',
          series: [
            ChartSeries(
              id: 'current',
              label: 'Current',
              points: [
                ChartPoint(0, 4, label: '2026-10-01'),
                ChartPoint(1, null, label: '2026-10-02'),
                ChartPoint(2, 0, label: '2026-10-03'),
              ],
            ),
          ],
        ),
      ),
      width: 720,
    );
    final chart = t.widget<LineChart>(find.byType(LineChart));
    final finiteSpots = chart.data.lineBarsData
        .expand((b) => b.spots)
        .where((s) => !s.isNull())
        .toList();
    expect(finiteSpots.where((s) => s.x == 1), isEmpty);
    expect(finiteSpots.any((s) => s.x == 2 && s.y == 0), isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('reduced motion uses immediate chart updates', (t) async {
    await pumpStudio(
      t,
      const TimeSeriesChart(
        unit: 'events',
        series: [
          ChartSeries(
            id: 'a',
            label: 'A',
            points: [ChartPoint(0, 1, label: '2026-10-01')],
          ),
        ],
      ),
      reducedMotion: true,
    );
    final chart = t.widget<LineChart>(find.byType(LineChart));
    expect(chart.duration, Duration.zero);
    expect(t.takeException(), isNull);
  });

  testWidgets('six series remain distinguishable when palette colors repeat', (t) async {
    await pumpStudio(
      t,
      TimeSeriesChart(
        unit: 'players',
        series: [
          for (var i = 0; i < 6; i++)
            ChartSeries(
              id: 'g$i',
              label: 'Group $i',
              points: [
                ChartPoint(0, i.toDouble(), label: 'Day 0'),
                ChartPoint(1, i + 1.0, label: 'Day 1'),
              ],
            ),
        ],
      ),
    );
    final data = t.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.lineBarsData[0].color, data.lineBarsData[4].color);
    expect(data.lineBarsData[4].dashArray, isNot(data.lineBarsData[0].dashArray));
  });

  testWidgets('single-point chart shows a marker and nonzero domain', (t) async {
    await pumpStudio(
      t,
      const TimeSeriesChart(
        unit: 'events',
        series: [
          ChartSeries(
            id: 'a',
            label: 'A',
            points: [ChartPoint(0, 0, label: 'day')],
          ),
        ],
      ),
    );
    final d = t.widget<LineChart>(find.byType(LineChart)).data;
    expect(d.maxX, greaterThan(d.minX));
    expect(d.maxY, greaterThan(d.minY));
    expect(d.lineBarsData.single.dotData.show, isTrue);
  });

  testWidgets('all-gap input does not fabricate a zero plot', (t) async {
    await pumpStudio(
      t,
      const TimeSeriesChart(
        unit: 'events',
        series: [
          ChartSeries(
            id: 'a',
            label: 'A',
            points: [ChartPoint(0, null, label: 'day')],
          ),
        ],
      ),
    );
    expect(find.text('No observations available'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);

    await pumpStudio(
      t,
      const TimeSeriesChart(unit: 'events', series: []),
    );
    expect(find.text('No observations available'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('zero bars are retained but missing bars are absent', (t) async {
    await pumpStudio(
      t,
      const TimeSeriesChart(
        unit: 'events',
        kind: TimeChartKind.bars,
        series: [
          ChartSeries(
            id: 'a',
            label: 'A',
            points: [
              ChartPoint(0, 0, label: 'stored zero'),
              ChartPoint(1, null, label: 'missing'),
              ChartPoint(2, 0, label: 'stored zero again'),
            ],
          ),
        ],
      ),
    );
    final d = t.widget<BarChart>(find.byType(BarChart)).data;
    expect(d.barGroups.map((g) => g.x), [0, 2]);
    expect(d.barGroups.expand((g) => g.barRods).every((r) => r.toY == 0), isTrue);
    expect(d.maxY, greaterThan(d.minY));
  });

  testWidgets('fractional bar buckets retain separate ordinal identities', (t) async {
    await pumpStudio(
      t,
      const TimeSeriesChart(
        unit: 'events',
        kind: TimeChartKind.bars,
        series: [
          ChartSeries(
            id: 'a',
            label: 'A',
            points: [
              ChartPoint(0.1, 4, label: 'bucket A'),
              ChartPoint(0.2, 7, label: 'bucket B'),
            ],
          ),
        ],
      ),
    );
    final d = t.widget<BarChart>(find.byType(BarChart)).data;
    expect(d.barGroups.map((g) => g.x), [0, 1]);
    expect(d.barGroups.expand((g) => g.barRods).map((r) => r.toY), [4, 7]);
  });

  testWidgets('boundary tooltip keeps callback length and suppresses duplicate', (t) async {
    await pumpStudio(
      t,
      const TimeSeriesChart(
        unit: 'events',
        series: [
          ChartSeries(
            id: 'a',
            label: 'Actual',
            points: [
              ChartPoint(0, 1, label: 'day0'),
              ChartPoint(1, 2, label: 'day1', incomplete: true),
              ChartPoint(2, 3, label: 'day2'),
              ChartPoint(3, 4, label: 'day3'),
            ],
          ),
        ],
      ),
    );
    final d = t.widget<LineChart>(find.byType(LineChart)).data;
    final touched = <LineBarSpot>[];
    for (var i = 0; i < d.lineBarsData.length; i++) {
      final bar = d.lineBarsData[i];
      for (final spot in bar.spots.where((s) => s.x == 2)) {
        touched.add(LineBarSpot(bar, i, spot));
      }
    }
    expect(touched, hasLength(2));
    final items = d.lineTouchData.touchTooltipData.getTooltipItems(touched);
    expect(items, hasLength(touched.length));
    expect(items.whereType<LineTooltipItem>(), hasLength(1));
    expect(items.whereType<LineTooltipItem>().single.text, contains('day2'));
  });

  testWidgets('gap topology change remounts plot even with same series ID', (t) async {
    Future<void> show(bool gap) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeSeriesChart(
              key: const ValueKey('same-chart'),
              unit: 'events',
              series: [
                ChartSeries(
                  id: 'a',
                  label: 'A',
                  points: [
                    const ChartPoint(0, 1, label: 'day0'),
                    ChartPoint(1, gap ? null : 2, label: 'day1'),
                    const ChartPoint(2, 3, label: 'day2'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    await show(false);
    final first = t.widget<LineChart>(find.byType(LineChart)).key;
    await show(true);
    final second = t.widget<LineChart>(find.byType(LineChart)).key;
    expect(first, isNotNull);
    expect(second, isNot(first));
    expect(t.takeException(), isNull);
  });

  testWidgets('signed bars retain signed values and readable precision', (t) async {
    await pumpStudio(
      t,
      DivergingBarChart(
        unit: 'effect size',
        values: const [
          RankedValue('negative', 'Negative', -0.95),
          RankedValue('positive', 'Positive', 0.67),
        ],
        valueFormatter: (v) => fmtDecimal(v.toDouble(), digits: 2),
      ),
    );
    expect(find.textContaining('-0.95'), findsWidgets);
    expect(find.textContaining('0.67'), findsWidgets);
    final values = t.widget<DivergingBarChart>(find.byType(DivergingBarChart)).values;
    expect(values.map((v) => v.value), [-0.95, 0.67]);
    final zero = t.getRect(find.byKey(const ValueKey('diverging-zero-guide'))).center.dx;
    expect(
      t.getRect(find.byKey(const ValueKey('ranked-bar:negative'))).center.dx,
      lessThan(zero),
    );
    expect(
      t.getRect(find.byKey(const ValueKey('ranked-bar:positive'))).center.dx,
      greaterThan(zero),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('long frame content grows outside its plot across themes', (t) async {
    for (final style in AppStyle.values) {
      await pumpStudio(
        t,
        ChartFrame(
          title: longIdentifier,
          unit: 'events',
          legend: [Text(longIdentifier)],
          actions: [
            FilledButton(
              onPressed: () {},
              child: const Text('Refresh data'),
            ),
          ],
          dataView: const Text('Exact value 4'),
          child: const SizedBox(key: ValueKey('plot'), height: 240),
        ),
        style: style,
      );
      expect(
        t.getSize(find.byKey(const ValueKey('plot'))).height,
        greaterThanOrEqualTo(200),
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('motion gates plot while exact data remains current', (t) async {
    Future<void> show(int revision, {bool reduced = false, bool active = true}) =>
        t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(720, 1200),
                disableAnimations: reduced,
              ),
              child: Scaffold(
                body: TickerMode(
                  enabled: active,
                  child: Column(
                    children: [
                      Text('Exact $revision'),
                      ChartMotion(
                        key: const ValueKey('motion'),
                        dataRevision: revision,
                        child: const SizedBox(width: 300, height: 240),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    bool ignored() =>
        t.widget<IgnorePointer>(find.byKey(const ValueKey('chart-motion-plot'))).ignoring;

    await show(1);
    expect(ignored(), isTrue);
    await t.pump(const Duration(milliseconds: 401));
    expect(ignored(), isFalse);

    await show(2);
    expect(find.text('Exact 2'), findsOneWidget);
    expect(ignored(), isTrue);
    await t.pump(const Duration(milliseconds: 351));
    expect(ignored(), isFalse);

    await show(3, active: false);
    expect(ignored(), isFalse);

    await show(3, active: true);
    expect(ignored(), isFalse);

    await show(4, reduced: true);
    expect(ignored(), isFalse);
    expect(t.hasRunningAnimations, isFalse);
  });
}
