import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/analytics_tokens.dart';
import '../../widgets/metric_line_chart.dart';

class AnomaliesTab extends ConsumerStatefulWidget {
  const AnomaliesTab({super.key});

  @override
  ConsumerState<AnomaliesTab> createState() => _AnomaliesTabState();
}

class _AnomaliesTabState extends ConsumerState<AnomaliesTab> {
  int? _selectedIdx;

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(filtersProvider);
    final async = ref.watch(anomaliesProvider(filters));
    final tokens = AnalyticsTokens.of(context);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (res) {
        if (res.reason == 'too_short') {
          return const Center(child: Text('Range shorter than 8 days (too short for rolling baseline).'));
        }
        if (res.alerts.isEmpty) {
          return const Center(child: Text('No anomalies detected in this range (|z| < 3 for all series).'));
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Anomaly Alerts', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Sudden spikes or drops flagged against rolling 14-day median baseline (|z| ≥ 3.0).',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < res.alerts.length; i++) ...[
              _buildAlertCard(i, res.alerts[i], tokens),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAlertCard(int idx, AnomalyAlert alert, AnalyticsTokens tokens) {
    final isSelected = _selectedIdx == idx;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedIdx = isSelected ? null : idx;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      alert.message,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  Chip(
                    label: Text('z = ${alert.z.toStringAsFixed(1)}'),
                    backgroundColor: alert.z > 0
                        ? tokens.good.withValues(alpha: 0.15)
                        : tokens.bad.withValues(alpha: 0.15),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Median baseline: ${alert.median} · MAD: ${alert.mad} · Day: ${alert.day}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (isSelected && alert.history.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  '${alert.series} Baseline History',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: MetricLineChart(
                    title: alert.series,
                    days: [for (final p in alert.history) p.day],
                    values: [for (final p in alert.history) p.value],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
