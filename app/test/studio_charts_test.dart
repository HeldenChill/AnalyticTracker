import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/charts/chart_frame.dart';
import 'package:analytic_app/src/widgets/charts/chart_models.dart';
import 'package:analytic_app/src/widgets/charts/chart_motion.dart';
import 'package:analytic_app/src/widgets/charts/diverging_bar_chart.dart';
import 'package:analytic_app/src/widgets/charts/ranked_bar_chart.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_app/src/widgets/format.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/bar_chart/bar_chart_renderer.dart';
import 'package:fl_chart/src/extensions/bar_chart_data_extension.dart';
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
    expect(d.barGroups.map((g) => g.x), [0, 1, 2]);
    expect(d.barGroups.map((g) => g.barRods.length), [1, 0, 1]);
    expect(d.barGroups[0].barRods.single.toY, 0);
    expect(d.barGroups[2].barRods.single.toY, 0);
    expect(d.maxY, greaterThan(d.minY));
  });

  testWidgets('blank bar bucket keeps physical space without a zero rod', (t) async {
    await pumpRepairChart(
      t,
      const TimeSeriesChart(
        kind: TimeChartKind.bars,
        unit: 'events',
        series: [
          ChartSeries(
            id: 'primary',
            label: 'Current',
            points: [
              ChartPoint(.1, 4, label: 'first'),
              ChartPoint(.2, null, label: 'missing'),
              ChartPoint(900, 8, label: 'last'),
            ],
          ),
        ],
      ),
      reduced: true,
    );
    final d = t.widget<BarChart>(find.byType(BarChart)).data;
    expect(d.barGroups.map((g) => g.x), [0, 1, 2]);
    expect(d.barGroups[1].barRods, isEmpty);
    expect(d.barGroups[0].barRods.single.toY, 4);
    expect(d.barGroups[2].barRods.single.toY, 8);
    final positions = d.calculateGroupsX(240);
    expect(positions.length, 3);
    expect(positions[0], lessThan(positions[1]));
    expect(positions[1], lessThan(positions[2]));
    expect(
      (positions[2] - positions[0]) / 2,
      closeTo(positions[1] - positions[0], .01),
    );
    expect(find.text('missing'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('bar tooltip maps sparse rods to original measured series', (t) async {
    await pumpRepairChart(
      t,
      const TimeSeriesChart(
        kind: TimeChartKind.bars,
        percentage: true,
        unit: '%',
        series: [
          ChartSeries(
            id: 'a',
            label: 'A missing',
            points: [
              ChartPoint(.1, null, label: 'bucket A'),
              ChartPoint(.2, .5, label: 'bucket B'),
            ],
          ),
          ChartSeries(
            id: 'b',
            label: 'B actual',
            points: [
              ChartPoint(.1, .3, label: 'bucket A', incomplete: true),
              ChartPoint(.2, .7, label: 'bucket B'),
            ],
          ),
        ],
      ),
      reduced: true,
    );
    final d = t.widget<BarChart>(find.byType(BarChart)).data;
    final group = d.barGroups.first;
    final tip = d.barTouchData.touchTooltipData;
    final item = tip.getTooltipItem(
      group,
      0,
      group.barRods.first.copyWith(toY: .99),
      0,
    )!;
    expect(item.text, contains('bucket A'));
    expect(item.text, contains('B actual'));
    expect(item.text, contains('30.0%'));
    expect(item.text, contains('partial'));
    expect(item.text, isNot(contains('99.0%')));
    expect(item.text, isNot(contains('%%')));
    expect(tip.fitInsideHorizontally && tip.fitInsideVertically, isTrue);
    expect(tip.maxContentWidth, lessThanOrEqualTo(280));
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

  testWidgets('actual renderer phase matches gate and topology', (t) async {
    Future<void> show(double y, {bool gap = false, bool active = true, bool reduced = false}) =>
        pumpRepairChart(
          t,
          TimeSeriesChart(
            key: const ValueKey('stable-chart'),
            unit: 'events',
            series: [
              ChartSeries(
                id: 'primary',
                label: 'Current',
                points: [
                  ChartPoint(0, y, label: 'a'),
                  ChartPoint(1, gap ? null : 2, label: 'b'),
                ],
              ),
            ],
          ),
          active: active,
          reduced: reduced,
        );
    bool gated() =>
        t.widget<IgnorePointer>(find.byKey(const ValueKey('chart-motion-plot'))).ignoring;
    await show(1);
    final initialKey = t.widget<LineChart>(find.byType(LineChart)).key;
    expect(t.widget<LineChart>(find.byType(LineChart)).duration, Duration.zero);
    expect(gated(), isTrue);
    await t.pump(const Duration(milliseconds: 401));
    expect(gated(), isFalse);
    await show(3);
    expect(t.widget<LineChart>(find.byType(LineChart)).key, initialKey);
    expect(t.widget<LineChart>(find.byType(LineChart)).duration, const Duration(milliseconds: 350));
    expect(gated(), isTrue);
    await t.pump(const Duration(milliseconds: 351));
    expect(gated(), isFalse);
    await show(3, gap: true);
    expect(t.widget<LineChart>(find.byType(LineChart)).key, isNot(initialKey));
    expect(t.widget<LineChart>(find.byType(LineChart)).duration, Duration.zero);
    final context = t.element(find.byType(LineChart));
    expect(ChartMotion.of(context).markOpacity, lessThan(1));
    await show(4, gap: true, active: false);
    expect(t.widget<LineChart>(find.byType(LineChart)).duration, Duration.zero);
    expect(ChartMotion.of(t.element(find.byType(LineChart))).markOpacity, 1);
    expect(gated(), isFalse);
    await show(4, gap: true, active: true);
    expect(gated(), isFalse);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('ranked horizontal bar motion synchronizes geometry and opacity', (t) async {
    Future<void> show(double val, {bool active = true, bool reduced = false}) =>
        pumpRepairChart(
          t,
          RankedBarChart(
            values: [
              RankedValue('a', 'Alpha', val),
              const RankedValue('max', 'Max', 100),
            ],
            unit: 'events',
          ),
          active: active,
          reduced: reduced,
        );

    await show(50);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('50 events'), findsOneWidget);
    final context = t.element(find.byKey(const ValueKey('ranked-bar:a')));
    expect(ChartMotion.of(context).markOpacity, lessThan(1.0));
    await t.pump(const Duration(milliseconds: 401));
    expect(ChartMotion.of(t.element(find.byKey(const ValueKey('ranked-bar:a')))).markOpacity, 1.0);
    final initialWidth = t.getRect(find.byKey(const ValueKey('ranked-bar:a'))).width;

    await show(80);
    await t.pump(const Duration(milliseconds: 175));
    final midWidth = t.getRect(find.byKey(const ValueKey('ranked-bar:a'))).width;
    expect(midWidth, greaterThan(initialWidth));
    await t.pump(const Duration(milliseconds: 176));
    final endWidth = t.getRect(find.byKey(const ValueKey('ranked-bar:a'))).width;
    expect(endWidth, greaterThan(midWidth));

    await show(20, reduced: true);
    expect(t.hasRunningAnimations, isFalse);
    expect(find.text('20 events'), findsOneWidget);
  });

  testWidgets('ranked names and exact values fit natural rows', (t) async {
    final name = List.filled(30, 'VeryLongEventName').join();
    const number = 123456789012.0;
    for (final diverging in [false, true]) {
      final rows = [RankedValue('long', name, number)];
      final chart = diverging
          ? DivergingBarChart(
              values: rows,
              unit: 'events',
              valueFormatter: (n) => n.toStringAsFixed(0),
            )
          : RankedBarChart(
              values: rows,
              unit: 'events',
              valueFormatter: (n) => n.toStringAsFixed(0),
            );
      await pumpRepairChart(t, chart, width: 280, scale: 1.5, bold: true, reduced: true);
      expect(t.takeException(), isNull);
      expectCompleteWrappedText(t, find.text(name));
      expectCompleteWrappedText(t, find.text('123456789012 events'));
    }
  });

  testWidgets('actual dense chart axes fit across themes widths and larger text', (t) async {
    final points = [
      for (var i = 0; i < 31; i++)
        ChartPoint(i.toDouble(), (i + 1).toDouble(), label: '2026-10-${i + 1}')
    ];
    for (final style in AppStyle.values) {
      for (final width in [280.0, 320.0, 720.0]) {
        for (final kind in TimeChartKind.values) {
          await pumpRepairChart(
            t,
            TimeSeriesChart(
              kind: kind,
              unit: 'events',
              valueFormatter: (v) => '${v.toStringAsFixed(2)} measured events',
              series: [ChartSeries(id: 'primary', label: 'Current', points: points)],
            ),
            style: style,
            width: width,
            scale: 1.5,
            bold: true,
            reduced: true,
          );
          expect(t.takeException(), isNull);
          final labels = find.byWidgetPredicate((w) {
            if (w is! Text || w.key is! ValueKey<String>) return false;
            final key = (w.key! as ValueKey<String>).value;
            return key.startsWith('chart-x-tick:') || key.startsWith('chart-y-tick:');
          });
          expect(labels, findsWidgets);
          for (var i = 0; i < labels.evaluate().length; i++) {
            final label = labels.at(i);
            expectCompleteWrappedText(t, label);
            final rect = t.getRect(label);
            expect(rect.left, greaterThanOrEqualTo(-.5));
            expect(rect.right, lessThanOrEqualTo(width + .5));
          }
          expect(
            t.getSize(find.byKey(const ValueKey('chart-mark-area'))).height,
            greaterThanOrEqualTo(80),
          );
        }
      }
    }
  });

  for (final reduced in [false, true]) {
    testWidgets('mid-animation ${reduced ? 'reduced motion' : 'inactive ticker'} snaps ranked geometry', (t) async {
      Future<void> render(double n, {bool active = true, bool reduce = false}) => pumpRepairChart(t,
        RankedBarChart(values: [RankedValue('a', 'A', n), const RankedValue('b', 'B', 20)],
          unit: 'events'), active: active, reduced: reduce);
      double factor() => t.widget<FractionallySizedBox>(find.descendant(
        of: find.byKey(const ValueKey('ranked-bar:a')), matching: find.byType(FractionallySizedBox))).widthFactor!;
      await render(10); await t.pump(const Duration(milliseconds: 401));
      await render(20); await t.pump(const Duration(milliseconds: 100));
      expect(factor(), lessThan(1));
      await render(20, active: reduced, reduce: reduced);
      expect(factor(), 1);
    });

    testWidgets('mid-animation ${reduced ? 'reduced motion' : 'inactive ticker'} snaps diverging positive geometry', (t) async {
      Future<void> render(double n, {bool active = true, bool reduce = false}) => pumpRepairChart(t,
        DivergingBarChart(values: [RankedValue('a', 'A', n), const RankedValue('b', 'B', -20)],
          unit: 'events'), active: active, reduced: reduce);
      double factor() => t.widget<FractionallySizedBox>(find.descendant(
        of: find.byKey(const ValueKey('ranked-bar:a')), matching: find.byType(FractionallySizedBox))).widthFactor!;
      await render(10); await t.pump(const Duration(milliseconds: 401));
      await render(20); await t.pump(const Duration(milliseconds: 100));
      expect(factor(), lessThan(1));
      await render(20, active: reduced, reduce: reduced);
      expect(factor(), 1);
    });

    testWidgets('mid-animation ${reduced ? 'reduced motion' : 'inactive ticker'} snaps diverging negative geometry', (t) async {
      Future<void> render(double n, {bool active = true, bool reduce = false}) => pumpRepairChart(t,
        DivergingBarChart(values: [RankedValue('a', 'A', -n), const RankedValue('b', 'B', 20)],
          unit: 'events'), active: active, reduced: reduce);
      double factor() => t.widget<FractionallySizedBox>(find.descendant(
        of: find.byKey(const ValueKey('ranked-bar:a')), matching: find.byType(FractionallySizedBox))).widthFactor!;
      await render(10); await t.pump(const Duration(milliseconds: 401));
      await render(20); await t.pump(const Duration(milliseconds: 100));
      expect(factor(), lessThan(1));
      await render(20, active: reduced, reduce: reduced);
      expect(factor(), 1);
    });
  }

  testWidgets('mid-animation accessibleNavigation snaps ranked geometry', (t) async {
    Future<void> render(double n, {bool accessible = false}) => t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(accessibleNavigation: accessible),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: RankedBarChart(
                values: [RankedValue('a', 'A', n), const RankedValue('b', 'B', 20)],
                unit: 'events',
              ),
            ),
          ),
        ),
      ),
    ));
    double factor() => t.widget<FractionallySizedBox>(find.descendant(
      of: find.byKey(const ValueKey('ranked-bar:a')), matching: find.byType(FractionallySizedBox))).widthFactor!;
    await render(10); await t.pump(const Duration(milliseconds: 401));
    await render(20); await t.pump(const Duration(milliseconds: 100));
    expect(factor(), lessThan(1));
    await render(20, accessible: true);
    expect(factor(), 1);
  });

  for (final width in [720.0, 1024.0, 1440.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('sparse grouped bar date label aligns at width $width scale $scale', (t) async {
        final series = [for (var i = 0; i < 20; i++) ChartSeries(id: 's$i', label: 'S$i',
          points: [ChartPoint(0, 1, label: 'first'),
            ChartPoint(1, i == 0 ? 2 : null, label: 'middle'),
            ChartPoint(2, i == 0 ? 3 : null, label: 'last')])];
        await t.pumpWidget(MaterialApp(home: MediaQuery(data: MediaQueryData(disableAnimations: true, textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: width,
            child: SingleChildScrollView(child: TimeSeriesChart(series: series, unit: 'events', kind: TimeChartKind.bars))))))));
        final leafFinder = find.byType(BarChartLeaf);
        final leaf = t.widget<BarChartLeaf>(leafFinder);
        final rect = t.getRect(leafFinder);
        final centers = leaf.targetData.calculateGroupsX(rect.width);
        final label = t.getRect(find.byKey(const ValueKey('chart-x-tick:1.0')));
        expect(label.center.dx, closeTo(rect.left + centers[1], .5));
      });
    }
  }

  testWidgets('line chart source tick alignment matches plot geometry', (t) async {
    const series = [
      ChartSeries(id: 's1', label: 'S1', points: [
        ChartPoint(0, 10, label: 'd0'),
        ChartPoint(5, 20, label: 'd5'),
        ChartPoint(10, 30, label: 'd10'),
      ]),
    ];
    await t.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(disableAnimations: true),
      child: const Scaffold(body: SizedBox(width: 720,
        child: TimeSeriesChart(series: series, unit: 'events', kind: TimeChartKind.line))))));
    expect(find.byKey(const ValueKey('chart-x-tick:0.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('chart-x-tick:10.0')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('empty and single bucket bar charts render without crash', (t) async {
    for (final series in [
      <ChartSeries>[],
      const [ChartSeries(id: 's', label: 'S', points: [ChartPoint(0, 5, label: 'one')])],
    ]) {
      await t.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: SizedBox(width: 720,
          child: TimeSeriesChart(series: series, unit: 'events', kind: TimeChartKind.bars))))));
      expect(t.takeException(), isNull);
    }
  });
}
