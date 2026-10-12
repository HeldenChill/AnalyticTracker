import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import 'format.dart';
import '../view_models/events_view_model.dart';
import 'charts/chart_models.dart';
import 'charts/time_series_chart.dart';
import 'studio_layout.dart';

class EventDetailPanel extends StatelessWidget {
  const EventDetailPanel({
    super.key,
    required this.event,
    required this.filters,
    required this.onClose,
    this.onExploreParameters,
  });

  final EventRowSummary event;
  final Filters filters;
  final VoidCallback onClose;
  final ValueChanged<String>? onExploreParameters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String changeLabel;
    Color? changeColor;
    switch (event.change.kind) {
      case ChangeKind.percent:
        final f = event.change.fraction ?? 0.0;
        final sign = f > 0 ? '+' : '';
        changeLabel = '$sign${(f * 100).toStringAsFixed(1)}%';
        changeColor = f >= 0 ? Colors.green : Colors.red;
        break;
      case ChangeKind.newActivity:
        changeLabel = 'New';
        changeColor = Colors.blue;
        break;
      case ChangeKind.unchanged:
        changeLabel = '0.0%';
        changeColor = theme.colorScheme.onSurfaceVariant;
        break;
      case ChangeKind.unavailable:
        changeLabel = '—';
        changeColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return Card(
      key: const ValueKey('event-detail-panel'),
      elevation: 2,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event details',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-event-detail'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close details',
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 16),
            StudioGrid(
              minChildWidth: 160,
              maxColumns: 4,
              gap: 12,
              children: [
                StudioMetric(
                  title: 'Occurrences',
                  value: fmtCount(event.current),
                  detail: 'In selected range',
                ),
                StudioMetric(
                  title: 'Volume share',
                  value: '${(event.share * 100).toStringAsFixed(1)}%',
                  detail: 'Of all event occurrences',
                ),
                StudioMetric(
                  title: 'Previous period',
                  value: event.previous != null ? fmtCount(event.previous!) : '—',
                  detail: 'Prior equivalent days',
                ),
                StudioMetric(
                  title: 'Period change',
                  value: changeLabel,
                  detail: event.change.kind == ChangeKind.percent
                      ? 'Comparison change'
                      : event.change.kind == ChangeKind.newActivity
                          ? 'New activity'
                          : 'Unavailable',
                  badge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      changeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Daily activity',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TimeSeriesChart(
              series: [
                ChartSeries(
                  id: 'current',
                  label: event.name,
                  points: event.daily,
                ),
              ],
              unit: 'occurrences',
              plotHeight: 180,
            ),
            if (onExploreParameters != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const ValueKey('explore-parameters-btn'),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Explore parameters'),
                  onPressed: () => onExploreParameters!(event.name),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
