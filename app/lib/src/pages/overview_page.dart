import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/error_retry.dart';
import '../widgets/format.dart';
import '../widgets/kpi_card.dart';
import '../widgets/metric_line_chart.dart';

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(overviewProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(overviewProvider(f))),
          data: (d) => _OverviewBody(data: d),
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
    final days = [for (final d in data.daily) d.day];
    final empty = data.daily.every((d) => d.dau == 0 && d.newUsers == 0 && d.sessions == 0 && d.uninstalls == 0);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (empty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('No data in this range'))),
          ),
        Wrap(spacing: 12, runSpacing: 12, children: [
          KpiCard(title: 'DAU (avg)', value: fmtDecimal(k.dau), delta: pctChange(k.dau, p?.dau)),
          KpiCard(title: 'New users', value: '${k.newUsers}', delta: pctChange(k.newUsers, p?.newUsers)),
          KpiCard(title: 'Sessions', value: '${k.sessions}', delta: pctChange(k.sessions, p?.sessions)),
          KpiCard(
            title: 'Sessions / DAU',
            value: fmtDecimal(k.sessionsPerDau),
            delta: k.sessionsPerDau == null ? null : pctChange(k.sessionsPerDau!, p?.sessionsPerDau),
          ),
          KpiCard(
            title: 'Playtime / DAU',
            value: '${fmtDecimal(k.playtimeMinPerDau)} min',
            delta: k.playtimeMinPerDau == null ? null : pctChange(k.playtimeMinPerDau!, p?.playtimeMinPerDau),
          ),
          KpiCard(
            title: 'Uninstalls',
            value: '${k.uninstalls}',
            delta: pctChange(k.uninstalls, p?.uninstalls),
            higherIsBetter: false,
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          MetricLineChart(title: 'DAU', days: days, values: [for (final d in data.daily) d.dau]),
          MetricLineChart(title: 'New users', days: days, values: [for (final d in data.daily) d.newUsers]),
          MetricLineChart(title: 'Sessions', days: days, values: [for (final d in data.daily) d.sessions]),
          MetricLineChart(title: 'Uninstalls', days: days, values: [for (final d in data.daily) d.uninstalls]),
        ]),
      ],
    );
  }
}
