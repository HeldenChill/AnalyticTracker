import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/charts/time_series_chart.dart';
import '../widgets/dashboard_chart_data.dart';
import '../widgets/dashboard_chart_panel.dart';
import '../widgets/format.dart';
import '../widgets/kpi_card.dart';
import '../widgets/studio_async_panel.dart';
import '../widgets/studio_layout.dart';

import '../state/navigation.dart';
import '../state/refresh.dart';

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);

    return ActiveRequestScope(
      page: AppPage.overview,
      queryKey: (baseUrl, f),
      reload: () async {
        try {
          await Future.wait([
            ref.refresh(overviewProvider(f).future),
          ]);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<OverviewData>(
        queryKey: (baseUrl, f),
        value: ref.watch(overviewProvider(f)),
        onRetry: () => ref.invalidate(overviewProvider(f)),
        builder: (d) => _OverviewBody(data: d),
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.data});
  final OverviewData data;

  @override
  Widget build(BuildContext context) {
    final k = data.kpis;
    final p = data.previous;
    final empty = data.daily.every((d) => d.dau == 0 && d.newUsers == 0 && d.sessions == 0 && d.uninstalls == 0);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StudioHeading(
          title: 'Overview',
          subtitle: 'Daily active players, acquisition, engagement, and uninstalls',
        ),
        const SizedBox(height: 16),
        if (empty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('No data in this range'))),
          ),
        // Six cards fill one row, else 3 + 3, else 2 per row, else 1 — never a lone orphan.
        LayoutBuilder(builder: (context, box) {
          const gap = 12.0;
          const minCard = 150.0;
          final int perRow;
          if (box.maxWidth >= 6 * minCard + 5 * gap) {
            perRow = 6;
          } else if (box.maxWidth >= 3 * minCard + 2 * gap) {
            perRow = 3;
          } else if (box.maxWidth >= 2 * minCard + gap) {
            perRow = 2;
          } else {
            perRow = 1;
          }
          final w = ((box.maxWidth - (perRow - 1) * gap) / perRow).floorToDouble();
          return Wrap(spacing: gap, runSpacing: gap, children: [
            KpiCard(width: w, title: 'DAU (avg)', value: fmtDecimal(k.dau), delta: pctChange(k.dau, p?.dau)),
            KpiCard(width: w, title: 'New users', value: '${k.newUsers}', delta: pctChange(k.newUsers, p?.newUsers)),
            KpiCard(width: w, title: 'Sessions', value: '${k.sessions}', delta: pctChange(k.sessions, p?.sessions)),
            KpiCard(
              width: w,
              title: 'Sessions / DAU',
              value: fmtDecimal(k.sessionsPerDau),
              delta: k.sessionsPerDau == null ? null : pctChange(k.sessionsPerDau!, p?.sessionsPerDau),
            ),
            KpiCard(
              width: w,
              title: 'Playtime / DAU',
              value: '${fmtDecimal(k.playtimeMinPerDau)} min',
              delta: k.playtimeMinPerDau == null ? null : pctChange(k.playtimeMinPerDau!, p?.playtimeMinPerDau),
            ),
            KpiCard(
              width: w,
              title: 'Uninstalls',
              value: '${k.uninstalls}',
              delta: pctChange(k.uninstalls, p?.uninstalls),
              higherIsBetter: false,
            ),
          ]);
        }),
        const SizedBox(height: 16),
        StudioGrid(
          minChildWidth: 360,
          maxColumns: 2,
          children: [
            DashboardChartPanel(
              key: const ValueKey('overview-dau-chart'),
              title: 'Daily active players',
              subtitle: 'Daily unique players',
              unit: 'players',
              kind: TimeChartKind.area,
              series: overviewChartSeries(data.daily, OverviewMetric.dau),
            ),
            DashboardChartPanel(
              key: const ValueKey('overview-new-users-chart'),
              title: 'New users',
              subtitle: 'Daily first installs',
              unit: 'players',
              kind: TimeChartKind.bars,
              series: overviewChartSeries(data.daily, OverviewMetric.newUsers),
            ),
            DashboardChartPanel(
              key: const ValueKey('overview-sessions-chart'),
              title: 'Sessions',
              subtitle: 'Daily session starts',
              unit: 'sessions',
              kind: TimeChartKind.area,
              series: overviewChartSeries(data.daily, OverviewMetric.sessions),
            ),
            DashboardChartPanel(
              key: const ValueKey('overview-uninstalls-chart'),
              title: 'Uninstalls',
              subtitle: 'Daily recorded removals',
              unit: 'removals',
              kind: TimeChartKind.bars,
              series: overviewChartSeries(data.daily, OverviewMetric.uninstalls),
            ),
          ],
        ),
      ],
    );
  }
}
