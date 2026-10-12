import 'package:analytic_app/src/widgets/studio_async_panel.dart';
import 'package:analytic_app/src/widgets/charts/chart_frame.dart';
import 'package:analytic_app/src/widgets/charts/chart_models.dart';
import 'package:analytic_app/src/widgets/charts/ranked_bar_chart.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/bar_chart/bar_chart_renderer.dart';
import 'package:fl_chart/src/chart/line_chart/line_chart_renderer.dart';
import 'package:fl_chart/src/extensions/bar_chart_data_extension.dart';

Future<void> show(WidgetTester t, Widget child, {bool active = true, bool reduced = true}) =>
  t.pumpWidget(MaterialApp(home: MediaQuery(data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 320,
      child: TickerMode(enabled: active, child: SingleChildScrollView(child: child))))))));

void main() {
  testWidgets('new-server loading does not display previous-server error', (t) async {
    final value = const AsyncLoading<int>().copyWithPrevious(
      AsyncError<int>(StateError('old server failed'), StackTrace.empty));
    expect(value.isLoading, isTrue);
    expect(value.hasError, isTrue);
    await show(t, StudioAsyncPanel<int>(queryKey: 'new-server', value: value,
      onRetry: () {}, builder: (n) => Text('$n')));
    expect(find.textContaining('old server failed'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  testWidgets('long legend fits supported bounded ChartFrame composition', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 320,
      child: ChartFrame(title: 'Long', unit: 'events', child: TimeSeriesChart(
        unit: 'events', series: [ChartSeries(id: 'reference',
          label: List.filled(30, 'long series name').join(' '),
          points: const [ChartPoint(0, 1, label: 'day')])]))))));
    expect(t.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets('mid-animation ${reduced ? 'reduced motion' : 'inactive ticker'} snaps ranked geometry', (t) async {
      Future<void> render(double n, {bool active = true, bool reduce = false}) => show(t,
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
  }
  testWidgets('large axis fallback grows outside plot-only height', (t) async {
    await show(t, TimeSeriesChart(unit: 'events',
      valueFormatter: (n) => List.filled(10, 'exact value $n').join(' '),
      series: const [ChartSeries(id: 'primary', label: 'P', points: [
        ChartPoint(0, 1, label: 'day0'), ChartPoint(1, 2, label: 'day1')])]), reduced: true);
    expect(find.byKey(const ValueKey('chart-scale-key')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('bar selection clears on measured data revision', (t) async {
    Future<void> render(double n) => show(t, TimeSeriesChart(unit: 'events',
      kind: TimeChartKind.bars, series: [ChartSeries(id: 'primary', label: 'P',
        points: [ChartPoint(0, n, label: 'day')])]), reduced: true);
    await render(10);
    final leaf = t.widget<BarChartLeaf>(find.byType(BarChartLeaf));
    final group = leaf.targetData.barGroups.first;
    final rod = group.barRods.first;
    leaf.targetData.barTouchData.touchCallback!(
      FlTapDownEvent(TapDownDetails(localPosition: const Offset(100, 100))),
      BarTouchResponse(touchLocation: const Offset(100, 100), touchChartCoordinate: const Offset(0, 10),
        spot: BarTouchedSpot(group, 0, rod, 0, null, -1, const FlSpot(0, 10), const Offset(100, 100))));
    await t.pump();
    expect(t.widget<BarChartLeaf>(find.byType(BarChartLeaf)).targetData.barGroups.first.showingTooltipIndicators, [0]);
    await render(20);
    expect(t.widget<BarChartLeaf>(find.byType(BarChartLeaf)).targetData.barGroups.first.showingTooltipIndicators, isEmpty);
  });
  testWidgets('sparse grouped bar date label aligns with actual rod group', (t) async {
    final series = [for (var i = 0; i < 20; i++) ChartSeries(id: 's$i', label: 'S$i',
      points: [ChartPoint(0, 1, label: 'first'),
        ChartPoint(1, i == 0 ? 2 : null, label: 'middle'),
        ChartPoint(2, i == 0 ? 3 : null, label: 'last')])];
    await t.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 720,
        child: SingleChildScrollView(child: TimeSeriesChart(series: series, unit: 'events', kind: TimeChartKind.bars))))))));
    final leafFinder = find.byType(BarChartLeaf);
    final leaf = t.widget<BarChartLeaf>(leafFinder);
    final rect = t.getRect(leafFinder);
    final centers = leaf.targetData.calculateGroupsX(rect.width);
    final label = t.getRect(find.byKey(const ValueKey('chart-x-tick:1.0')));
    expect(label.center.dx, closeTo(rect.left + centers[1], .5));
  });
  testWidgets('partial bar rendering differs from complete measured rod', (t) async {
    await show(t, const TimeSeriesChart(kind: TimeChartKind.bars, unit: 'events', series: [
      ChartSeries(id: 'primary', label: 'P', points: [
        ChartPoint(0, 1, label: 'complete'), ChartPoint(1, 1, label: 'partial', incomplete: true)])]));
    final d = t.widget<BarChart>(find.byType(BarChart)).data;
    final first = d.barGroups[0].barRods.first;
    final second = d.barGroups[1].barRods.first;
    expect((first.color, first.borderSide), isNot((second.color, second.borderSide)));
  });
  testWidgets('line tooltip cannot anchor to previous measured y after refresh', (t) async {
    Future<void> render(double n) => show(t, TimeSeriesChart(unit: 'events',
      series: [ChartSeries(id: 'primary', label: 'P',
        points: [ChartPoint(0, n, label: 'day')])]), reduced: true);
    await render(10);
    final initial = t.widget<LineChartLeaf>(find.byType(LineChartLeaf));
    final bar = initial.targetData.lineBarsData.first;
    initial.targetData.lineTouchData.touchCallback!(
      FlTapDownEvent(TapDownDetails(localPosition: const Offset(100, 100))),
      LineTouchResponse(touchLocation: const Offset(100, 100), touchChartCoordinate: const Offset(0, 10),
        lineBarSpots: [TouchLineBarSpot(bar, 0, bar.spots.first, 0)]));
    await t.pump(); await render(20);
    final current = t.widget<LineChartLeaf>(find.byType(LineChartLeaf)).targetData;
    expect(current.lineBarsData.first.spots.first.y, 20);
    expect(current.showingTooltipIndicators.first.showingSpots.first.y, 20);
  });
}
