import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../state/navigation.dart';
import '../../state/refresh.dart';
import '../../theme/analytics_tokens.dart';
import '../../widgets/charts/chart_frame.dart';
import '../../widgets/charts/chart_models.dart';
import '../../widgets/charts/time_series_chart.dart';
import '../../widgets/format.dart';
import '../../widgets/studio_async_panel.dart';

class AnomaliesTab extends ConsumerStatefulWidget {
  const AnomaliesTab({super.key});

  @override
  ConsumerState<AnomaliesTab> createState() => _AnomaliesTabState();
}

class _AnomaliesTabState extends ConsumerState<AnomaliesTab> {
  String? _selectedAlertKey;

  static String _unitForSeries(String series) {
    final s = series.toLowerCase();
    if (s == 'dau' || s == 'new_players') return 'players';
    if (s == 'sessions') return 'sessions';
    if (s.contains('completion') || s.contains('rate')) return 'percent';
    return 'events';
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);
    final tokens = AnalyticsTokens.of(context);

    return ActiveRequestScope(
      page: AppPage.analytic,
      analyticTab: 5,
      queryKey: (baseUrl, filters),
      reload: () async {
        try {
          await Future.wait([ref.refresh(anomaliesProvider(filters).future)]);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<AnomalyResult>(
      queryKey: (baseUrl, filters),
      value: ref.watch(anomaliesProvider(filters)),
      onRetry: () => ref.invalidate(anomaliesProvider(filters)),
      builder: (res) {
        if (res.reason == 'too_short') {
          return const Center(
            child: Text('Range shorter than 8 days (too short for rolling baseline).'),
          );
        }
        if (res.alerts.isEmpty) {
          return const Center(
            child: Text(
              'No alerts available for this range. Series with insufficient baseline history are not evaluated.',
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Anomaly Alerts', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Sudden spikes or drops flagged against rolling 14-day median baseline (|z| ≥ 3.0).',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              for (final alert in res.alerts) ...[
                _buildAlertCard(alert, tokens),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    ),
  );
  }

  Widget _buildAlertCard(AnomalyAlert alert, AnalyticsTokens tokens) {
    final key = '${alert.series}:${alert.day}';
    final isSelected = _selectedAlertKey == key;
    final theme = Theme.of(context);
    final unit = _unitForSeries(alert.series);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedAlertKey = isSelected ? null : key;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      alert.message,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('z = ${alert.z.toStringAsFixed(1)}'),
                    backgroundColor: alert.z > 0
                        ? tokens.good.withValues(alpha: 0.15)
                        : tokens.bad.withValues(alpha: 0.15),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Observed: ${fmtDecimal(alert.value, digits: 1)}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '· Median baseline: ${alert.median}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '· MAD: ${alert.mad}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '· Day: ${alert.day}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: isSelected ? _buildDetail(alert, unit) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(AnomalyAlert alert, String unit) {
    final actualPoints = <ChartPoint>[];
    final baselinePoints = <ChartPoint>[];

    if (alert.history.isNotEmpty) {
      final sorted = List.of(alert.history)..sort((a, b) => a.day.compareTo(b.day));
      final start = DateTime.tryParse(sorted.first.day);
      var end = DateTime.tryParse(sorted.last.day);
      final alertDt = DateTime.tryParse(alert.day);
      if (alertDt != null && end != null && alertDt.isAfter(end)) {
        end = alertDt;
      }

      if (start != null && end != null) {
        final historyMap = {for (final p in sorted) p.day: p.value};
        var current = start;
        var x = 0.0;
        while (!current.isAfter(end)) {
          final dayStr = current.toIso8601String().substring(0, 10);
          final val = historyMap[dayStr];
          actualPoints.add(ChartPoint(x, val, label: dayStr));
          baselinePoints.add(ChartPoint(x, alert.median, label: dayStr));
          current = current.add(const Duration(days: 1));
          x += 1.0;
        }
      } else {
        for (var i = 0; i < sorted.length; i++) {
          actualPoints.add(ChartPoint(i.toDouble(), sorted[i].value, label: sorted[i].day));
          baselinePoints.add(ChartPoint(i.toDouble(), alert.median, label: sorted[i].day));
        }
      }
    } else {
      actualPoints.add(ChartPoint(0, alert.value, label: alert.day));
      baselinePoints.add(ChartPoint(0, alert.median, label: alert.day));
    }

    final seriesList = [
      ChartSeries(
        id: 'actual',
        label: alert.series,
        points: actualPoints,
      ),
      ChartSeries(
        id: 'alert-baseline',
        label: 'Alert baseline median',
        points: baselinePoints,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          ChartFrame(
            title: '${alert.series} Baseline History',
            subtitle:
                'Target alert on ${alert.day}: observed ${alert.value} vs baseline median ${alert.median} (z = ${alert.z.toStringAsFixed(1)}).',
            unit: unit,
            plotHeight: 200,
            child: TimeSeriesChart(
              series: seriesList,
              unit: unit,
              percentage: unit == 'percent',
              plotHeight: 200,
            ),
          ),
        ],
      ),
    );
  }
}
