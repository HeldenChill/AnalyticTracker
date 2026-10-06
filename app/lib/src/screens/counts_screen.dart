import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/error_retry.dart';
import '../widgets/event_picker.dart';
import '../widgets/metric_line_chart.dart';

class CountsScreen extends ConsumerStatefulWidget {
  const CountsScreen({super.key});
  @override
  ConsumerState<CountsScreen> createState() => _CountsScreenState();
}

class _CountsScreenState extends ConsumerState<CountsScreen> {
  String? _event;

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(filtersProvider);
    final query = (filters: f, name: _event);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EventPicker(value: _event, allowAll: true, onChanged: (v) => setState(() => _event = v)),
        const SizedBox(height: 12),
        ref.watch(countsProvider(query)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(countsProvider(query))),
              data: (counts) {
                final days = daysBetween(f.from, f.to);
                final totals = {for (final d in days) d: 0};
                for (final c in counts) {
                  totals[c.day] = (totals[c.day] ?? 0) + c.count;
                }
                final sum = totals.values.fold<int>(0, (a, b) => a + b);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: $sum events'),
                    const SizedBox(height: 8),
                    MetricLineChart(
                      title: _event ?? 'All events',
                      days: days,
                      values: [for (final d in days) totals[d]!],
                    ),
                  ],
                );
              },
            ),
      ],
    );
  }
}
