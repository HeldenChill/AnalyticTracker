import 'package:analytic_app/src/widgets/studio_async_panel.dart';
import 'package:analytic_app/src/widgets/charts/time_series_chart.dart';
import 'package:analytic_app/src/widgets/charts/chart_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => ProbeState();
}
class ProbeState extends State<Probe> {
  @override
  Widget build(BuildContext context) => const Text('child');
}
void main() {
  testWidgets('bar gaps keep blank bucket group', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TimeSeriesChart(
      kind: TimeChartKind.bars, unit: 'events', series: [ChartSeries(id: 'primary', label: 'P',
        points: [ChartPoint(0, 1, label: 'day0'), ChartPoint(1, null, label: 'day1'), ChartPoint(2, 2, label: 'day2')])],
    ))));
    final data = t.widget<BarChart>(find.byType(BarChart)).data;
    expect(data.barGroups.map((g) => g.x).toList(), [0, 1, 2]);
  });
  testWidgets('bar tooltip includes original bucket label and unit', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TimeSeriesChart(
      kind: TimeChartKind.bars, unit: 'events', series: [ChartSeries(id: 'primary', label: 'P',
        points: [ChartPoint(0, 2, label: 'day0', incomplete: true)])],
    ))));
    final data = t.widget<BarChart>(find.byType(BarChart)).data;
    final group = data.barGroups.first;
    final item = data.barTouchData.touchTooltipData.getTooltipItem(group, 0, group.barRods.first, 0)!;
    expect(item.text, contains('day0'));
    expect(item.text, contains('events'));
    expect(item.text, contains('partial'));
  });
  testWidgets('inactive ticker renders immediate chart updates', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TickerMode(enabled: false,
      child: TimeSeriesChart(unit: 'events', series: [ChartSeries(id: 'primary', label: 'P',
        points: [ChartPoint(0, 2, label: 'day0')])]),
    ))));
    expect(t.widget<LineChart>(find.byType(LineChart)).duration, Duration.zero);
  });
  testWidgets('same-query refresh retains child state', (t) async {
    final value = ValueNotifier<AsyncValue<int>>(const AsyncData(7));
    addTearDown(value.dispose);
    await t.pumpWidget(MaterialApp(home: ValueListenableBuilder<AsyncValue<int>>(
      valueListenable: value,
      builder: (_, v, __) => StudioAsyncPanel<int>(queryKey: 'A', value: v,
        onRetry: () {}, builder: (_) => const Probe()),
    )));
    final before = t.state<ProbeState>(find.byType(Probe));
    value.value = const AsyncLoading<int>().copyWithPrevious(const AsyncData(7));
    await t.pump();
    expect(identical(before, t.state<ProbeState>(find.byType(Probe))), isTrue);
  });
  testWidgets('percentage axes remain zero to one', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TimeSeriesChart(
      percentage: true, unit: '%', series: [ChartSeries(id: 'primary', label: 'P',
        points: [ChartPoint(0, .3, label: 'day')])],
    ))));
    final data = t.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.minY, 0);
    expect(data.maxY, 1);
  });
  testWidgets('long real series legend wraps without overflow', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 320,
      child: TimeSeriesChart(unit: 'events', series: [ChartSeries(id: 'reference',
        label: List.filled(30, 'long series name').join(' '),
        points: const [ChartPoint(0, 1, label: 'day')])]),
    ))));
    expect(t.takeException(), isNull);
  });
}
