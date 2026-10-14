import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/charts/time_series_chart.dart';
import '../widgets/dashboard_chart_data.dart';
import '../widgets/dashboard_chart_panel.dart';
import '../widgets/stage_table.dart';
import '../widgets/studio_async_panel.dart';
import '../widgets/studio_layout.dart';

import '../state/event_vocabulary.dart';
import '../state/navigation.dart';
import '../state/refresh.dart';

class ProgressionPage extends ConsumerWidget {
  const ProgressionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);
    final vocabulary = ref.watch(effectiveVocabularyProvider);

    return ActiveRequestScope(
      page: AppPage.progression,
      queryKey: (baseUrl, f),
      reload: () async {
        try {
          await Future.wait([
            ref.refresh(progressionProvider(f).future),
          ]);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<ProgressionData>(
        queryKey: (baseUrl, f),
        value: ref.watch(progressionProvider(f)),
        onRetry: () => ref.invalidate(progressionProvider(f)),
        builder: (d) {
          if (d.stages.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const StudioHeading(
                  title: 'Progression',
                  subtitle: 'Player reach and difficulty, stage by stage',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No stage events yet — builds using ${[for (final id in const ['stg_start', 'stg_cmp', 'stg_fail']) vocabulary.eventLabel(id)].join(', ')} will appear here.',
                        textAlign: TextAlign.center,
                      ),
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
                title: 'Progression',
                subtitle: 'Player reach and difficulty, stage by stage',
              ),
              const SizedBox(height: 16),
              DashboardChartPanel(
                key: const ValueKey('progression-reach-chart'),
                title: 'Players reaching each stage',
                subtitle: 'Unique players · stage order preserved',
                unit: 'players',
                kind: TimeChartKind.bars,
                series:
                    progressionChartSeries(d.stages, ProgressionMetric.players),
              ),
              const SizedBox(height: 16),
              StudioGrid(
                minChildWidth: 360,
                maxColumns: 2,
                children: [
                  DashboardChartPanel(
                    key: const ValueKey('progression-win-rate-chart'),
                    title: 'Win rate',
                    subtitle: 'Completes ÷ (completes + fails)',
                    unit: 'win rate (%)',
                    percentage: true,
                    valueFormatter: formatDashboardRate,
                    series: progressionChartSeries(
                        d.stages, ProgressionMetric.winRate),
                  ),
                  DashboardChartPanel(
                    key: const ValueKey('progression-drop-off-chart'),
                    title: 'Stage drop-off',
                    subtitle: 'Versus the next numbered stage',
                    unit: 'drop-off (%)',
                    kind: TimeChartKind.bars,
                    percentage: false,
                    valueFormatter: formatDashboardRate,
                    series: progressionChartSeries(
                        d.stages, ProgressionMetric.dropOff),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                key: const ValueKey('progression-stage-details'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stage details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StageTable(stages: orderedStages(d.stages)),
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
