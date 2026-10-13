import 'dart:math' as math;

import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/charts/chart_axis_layout.dart';
import 'package:analytic_app/src/widgets/charts/chart_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('measureChartAxes calculates capacity, bounds and reservations', (tester) async {
    final buckets = [
      for (var i = 0; i < 31; i++)
        ChartPoint(i.toDouble(), (i * 10).toDouble(), label: 'Day ${i + 1}'),
    ];
    final bounds = const ChartBounds(0, 30, 0, 300);

    for (final style in AppStyle.values) {
      for (final scale in [1.0, 1.5]) {
        for (final bold in [false, true]) {
          late ChartAxisLayout layout;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(style),
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(scale),
                  boldText: bold,
                ),
                child: Builder(
                  builder: (context) {
                    layout = measureChartAxes(
                      context: context,
                      width: 320,
                      bounds: bounds,
                      buckets: buckets,
                      ordinalBars: true,
                      formatY: (y) => '\$${y.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 10),
                      plotHeight: 240,
                    );
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          );

          // Assert capacity limit
          final usable = math.max(1.0, 320 - layout.yReservedSize - 8);
          final expectedCapacity = math.max(2, (usable / 88).floor());
          expect(layout.xTicks.length, lessThanOrEqualTo(expectedCapacity));

          // Assert each selected label matches its source bucket
          for (final entry in layout.xTicks.entries) {
            final index = entry.key.toInt();
            expect(entry.value, buckets[index].label);
          }

          // Assert y reservation is at least independent TextPainter width + 8
          final effectiveStyle = TextStyle(
            fontSize: 10,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          );
          final painter = TextPainter(
            text: TextSpan(text: '\$300', style: effectiveStyle),
            textScaler: TextScaler.linear(scale),
            textDirection: TextDirection.ltr,
          )..layout();
          if (layout.yReservedSize > 0) {
            expect(layout.yReservedSize, greaterThanOrEqualTo(painter.width + 8));
          }
          painter.dispose();
        }
      }
    }
  });

  testWidgets('measureChartAxes rejects invalid inputs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(
              () => measureChartAxes(
                context: context,
                width: 0,
                bounds: const ChartBounds(0, 1, 0, 1),
                buckets: const [],
                ordinalBars: false,
                formatY: (y) => '$y',
                style: const TextStyle(),
              ),
              throwsArgumentError,
            );
            expect(
              () => measureChartAxes(
                context: context,
                width: 100,
                bounds: const ChartBounds(0, 1, 0, 1),
                buckets: const [ChartPoint(0, 1, label: 'a')],
                barCenters: const [0.1, 0.2], // mismatched count
                ordinalBars: true,
                formatY: (y) => '$y',
                style: const TextStyle(),
              ),
              throwsArgumentError,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('axis ticks use source coordinates and measured scaled style', (t) async {
    final buckets = [
      for (var i = 0; i < 31; i++)
        ChartPoint(i + .1, i.toDouble(), label: 'day $i')
    ];
    for (final theme in AppStyle.values) {
      for (final bars in [false, true]) {
        await t.pumpWidget(MaterialApp(
          theme: buildTheme(theme),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5), boldText: true),
            child: Builder(builder: (context) {
              final style = DefaultTextStyle.of(context)
                  .style
                  .merge(const TextStyle(fontSize: 10))
                  .copyWith(fontWeight: FontWeight.bold);
              String formatter(num n) => '${n.toStringAsFixed(2)} units';
              final layout = measureChartAxes(
                context: context,
                width: 320,
                bounds: const ChartBounds(.1, 30.1, 0, 30),
                buckets: buckets,
                ordinalBars: bars,
                formatY: formatter,
                style: style,
              );
              final usable = math.max(1.0, 320 - layout.yReservedSize - 8);
              final capacity = math.max(2, (usable / 88).floor());
              expect(layout.xTicks.length, lessThanOrEqualTo(capacity));
              for (final entry in layout.xTicks.entries) {
                final index = bars
                    ? entry.key.toInt()
                    : buckets.indexWhere((p) => p.x == entry.key);
                expect(index, greaterThanOrEqualTo(0));
                expect(entry.value, buckets[index].label);
              }
              final painter = TextPainter(
                text: TextSpan(text: formatter(30), style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              expect(layout.yReservedSize + .5, greaterThanOrEqualTo(painter.width + 8));
              painter.dispose();
              return const SizedBox.shrink();
            }),
          ),
        ));
      }
    }
  });

  testWidgets('fractional line axis never rounds into list indices', (t) async {
    await t.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      const buckets = [
        ChartPoint(.1, 1, label: 'A'),
        ChartPoint(.2, 2, label: 'B'),
        ChartPoint(900, 3, label: 'C')
      ];
      final layout = measureChartAxes(
        context: context,
        width: 720,
        bounds: const ChartBounds(.1, 900, 0, 3),
        buckets: buckets,
        ordinalBars: false,
        formatY: (v) => v.toStringAsFixed(0),
        style: const TextStyle(fontSize: 10),
      );
      expect(layout.xTicks, {.1: 'A', 900.0: 'C'});
      expect(layout.plotWidth, 720 - layout.yReservedSize);
      expect(layout.plotLeft, layout.yReservedSize);
      return const SizedBox.shrink();
    })));
  });

  group('spaceAroundCenters', () {
    test('returns empty for empty groups', () {
      expect(spaceAroundCenters(100, []), isEmpty);
    });

    test('centers single group', () {
      final centers = spaceAroundCenters(100, [20]);
      expect(centers, [50.0]);
    });

    test('centers equal groups with space around', () {
      final centers = spaceAroundCenters(100, [20, 20]);
      // sum=40, remaining=60, 4 gaps of 15.
      // group0: 15 + 10 = 25
      // group1: 15 + 20 + 30 + 10 = 75
      expect(centers, [25.0, 75.0]);
    });

    test('centers unequal groups matching fl_chart spacing', () {
      final centers = spaceAroundCenters(120, [10, 30, 20]);
      // sum=60, remaining=60, 6 half-gaps of 10.
      // halfGap = 10.
      // group0: 10 + 5 = 15. right=20.
      // group1: 20 + 10 + 15 = 45. right=60.
      // group2: 60 + 10 + 10 = 80. right=90.
      // (Wait, remaining = 120-60 = 60. halfGap = 60 / (2*3) = 10).
      // group0: x=0 + 10 + 5 = 15. x += 5 + 10 -> x=30.
      // group1: 30 + 10 + 15 = 55. x += 15 + 10 -> x=80.
      // group2: 80 + 10 + 10 = 100.
      expect(centers, [15.0, 55.0, 100.0]);
    });

    test('rejects invalid inputs', () {
      expect(() => spaceAroundCenters(0, [10]), throwsArgumentError);
      expect(() => spaceAroundCenters(-10, [10]), throwsArgumentError);
      expect(() => spaceAroundCenters(double.infinity, [10]), throwsArgumentError);
      expect(() => spaceAroundCenters(100, [-5]), throwsArgumentError);
      expect(() => spaceAroundCenters(100, [60, 50]), throwsArgumentError);
    });
  });
}
