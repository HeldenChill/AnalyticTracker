import 'dart:math' as math;

import 'package:analytic_shared/analytic_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/error_retry.dart';
import '../widgets/event_picker.dart';
import '../widgets/range_bar.dart';

class CountsScreen extends ConsumerStatefulWidget {
  const CountsScreen({super.key});
  @override
  ConsumerState<CountsScreen> createState() => _CountsScreenState();
}

class _CountsScreenState extends ConsumerState<CountsScreen> {
  DateTimeRange _range = defaultRange();
  String? _event;

  @override
  Widget build(BuildContext context) {
    final from = formatDay(_range.start);
    final to = formatDay(_range.end);
    final query = (from: from, to: to, name: _event);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            EventPicker(value: _event, allowAll: true, onChanged: (v) => setState(() => _event = v)),
            RangeBar(range: _range, onChanged: (r) => setState(() => _range = r)),
          ]),
        ),
        Expanded(
          child: ref.watch(countsProvider(query)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(countsProvider(query))),
                data: (counts) => _CountsChart(days: daysBetween(from, to), counts: counts),
              ),
        ),
      ],
    );
  }
}

class _CountsChart extends StatelessWidget {
  const _CountsChart({required this.days, required this.counts});
  final List<String> days;
  final List<EventCount> counts;

  @override
  Widget build(BuildContext context) {
    final totals = {for (final d in days) d: 0};
    for (final c in counts) {
      totals[c.day] = (totals[c.day] ?? 0) + c.count;
    }
    final sum = totals.values.fold<int>(0, (a, b) => a + b);
    final step = math.max(1, (days.length / 6).ceil()).toDouble();
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
    return Column(
      children: [
        Text('Total: $sum events'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 24, 8),
            child: LineChart(
              LineChartData(
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), totals[days[i]]!.toDouble()),
                    ],
                    dotData: const FlDotData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  topTitles: hidden,
                  rightTitles: hidden,
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: step,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (value != i.toDouble() || i < 0 || i >= days.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(days[i].substring(5), style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
