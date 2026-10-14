import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/charts/time_series_chart.dart';
import '../widgets/dashboard_chart_data.dart';
import '../widgets/dashboard_chart_panel.dart';
import '../widgets/retention_table.dart';
import '../widgets/studio_async_panel.dart';
import '../widgets/studio_layout.dart';

import '../state/navigation.dart';
import '../state/refresh.dart';

class RetentionPage extends ConsumerWidget {
  const RetentionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);

    return ActiveRequestScope(
      page: AppPage.retention,
      queryKey: (baseUrl, f),
      reload: () async {
        try {
          await Future.wait([
            ref.refresh(retentionProvider(f).future),
          ]);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<RetentionData>(
        queryKey: (baseUrl, f),
        value: ref.watch(retentionProvider(f)),
        onRetry: () => ref.invalidate(retentionProvider(f)),
        builder: (d) {
          if (d.cohorts.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                StudioHeading(
                  title: 'Retention',
                  subtitle: 'How often players return after their first install',
                ),
                SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No installs (first_open) in this range'),
                    ),
                  ),
                ),
              ],
            );
          }
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const StudioHeading(
                title: 'Retention',
                subtitle: 'How often players return after their first install',
              ),
              const SizedBox(height: 16),
              StudioGrid(
                minChildWidth: 220,
                maxColumns: 3,
                children: [
                  StudioMetric(
                    key: const ValueKey('retention-d1'),
                    title: 'Day 1 retention',
                    value: retentionAt(d, 1) == null ? '—' : formatDashboardRate(retentionAt(d, 1)!),
                    detail: 'Weighted by observable cohort size',
                  ),
                  StudioMetric(
                    key: const ValueKey('retention-d7'),
                    title: 'Day 7 retention',
                    value: retentionAt(d, 7) == null ? '—' : formatDashboardRate(retentionAt(d, 7)!),
                    detail: 'Weighted by observable cohort size',
                  ),
                  StudioMetric(
                    key: const ValueKey('retention-d14'),
                    title: 'Day 14 retention',
                    value: retentionAt(d, 14) == null ? '—' : formatDashboardRate(retentionAt(d, 14)!),
                    detail: 'Only observable cohort days included',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Only observable cohort days are included; unavailable days are not zero.${d.lastDataDay == null ? '' : ' Data through ${d.lastDataDay}.'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              DashboardChartPanel(
                key: const ValueKey('retention-curve'),
                title: 'Retention curve',
                subtitle: 'Weighted average · days since first install',
                unit: 'retained players (%)',
                kind: TimeChartKind.line,
                percentage: true,
                valueFormatter: formatDashboardRate,
                series: retentionChartSeries(d),
              ),
              const SizedBox(height: 16),
              Card(
                key: const ValueKey('retention-cohorts'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Install cohorts',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Blank cells are not yet observable.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RetentionTable(data: d),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
