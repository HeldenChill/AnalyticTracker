import 'dart:async';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../state/navigation.dart';
import '../state/refresh.dart';
import '../view_models/data_health_view_model.dart';
import '../view_models/storage_observations.dart';
import '../widgets/charts/chart_frame.dart';
import '../widgets/charts/chart_models.dart';
import '../widgets/charts/time_series_chart.dart';
import '../widgets/coverage_calendar.dart';
import '../widgets/studio_async_panel.dart';
import '../widgets/studio_layout.dart';
import '../widgets/studio_table.dart';

class DaysScreen extends ConsumerStatefulWidget {
  const DaysScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  ConsumerState<DaysScreen> createState() => _DaysScreenState();
}

class _DaysScreenState extends ConsumerState<DaysScreen>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;
  final ScrollController _scrollController = ScrollController();

  DateTime _readNow() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void didUpdateWidget(covariant DaysScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now) {
      _scheduleMidnight();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = _readNow();
    final next = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    final diff = next.difference(now);
    final duration = diff.isNegative ? const Duration(seconds: 1) : diff;
    _midnightTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnight();
    });
  }

  static String _formatDateTime(DateTime dt) {
    return '${formatDay(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _statusLabel(DayAvailability availability) {
    switch (availability) {
      case DayAvailability.stored:
        return 'Stored';
      case DayAvailability.missing:
        return 'Missing';
      case DayAvailability.incomplete:
        return 'May be incomplete';
      case DayAvailability.future:
        return 'Future';
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);
    final rows = ref.watch(daysProvider);

    return ActiveRequestScope(
      page: AppPage.dataHealth,
      queryKey: baseUrl,
      reload: () async {
        try {
          await Future.wait([ref.refresh(daysProvider.future)]);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<List<DayStat>>(
        queryKey: baseUrl,
        value: rows,
        onRetry: () => ref.invalidate(daysProvider),
        builder: (stored) {
          final model = buildDataHealth(stored, f, now: _readNow());
          return _buildHealthContent(model, f, hasAnyStorage: stored.isNotEmpty);
        },
      ),
    );
  }

  Widget _buildHealthContent(
    DataHealthViewModel model,
    Filters f, {
    required bool hasAnyStorage,
  }) {
    final theme = Theme.of(context);
    final reversedTimeline = model.timeline.reversed.toList();

    return ListView(
      key: const ValueKey('health-scroll-view'),
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        const StudioHeading(
          title: 'Data health',
          subtitle:
              'Stored raw data coverage. Gameplay filters do not apply.',
        ),
        const SizedBox(height: 24),
        if (!hasAnyStorage)
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No data yet. Run the daily pull on the server PC.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        StudioGrid(
          minChildWidth: 240,
          maxColumns: 4,
          children: [
            StudioMetric(
              key: const ValueKey('health-total-events'),
              title: 'Events stored',
              value: '${model.totalEvents}',
              detail: 'Selected interval ${f.from} to ${f.to}',
            ),
            StudioMetric(
              key: const ValueKey('health-completed-coverage'),
              title: 'Completed-day coverage',
              value: model.completedExpectedDays == 0
                  ? 'No completed days'
                  : '${model.completedStoredDays} / ${model.completedExpectedDays} (${(model.coverage! * 100).round()}%)',
              detail: 'Selected interval ${f.from} to ${f.to}',
            ),
            StudioMetric(
              title: 'Latest stored day',
              value: model.latestStoredDay ?? 'Unavailable',
              detail: 'All stored dates on this server',
            ),
            StudioMetric(
              title: 'Last import / pull',
              value: model.latestUpdate == null
                  ? 'Unknown'
                  : _formatDateTime(model.latestUpdate!.toLocal()),
              detail: 'All stored dates on this server',
            ),
          ],
        ),
        const SizedBox(height: 24),
        ChartFrame(
          title: 'Daily stored events',
          unit: 'events',
          dataView: _buildDataView(model),
          child: TimeSeriesChart(
            series: [
              ChartSeries(
                id: 'daily_events',
                label: 'Events',
                points: [
                  for (var i = 0; i < model.timeline.length; i++)
                    ChartPoint(
                      i.toDouble(),
                      model.timeline[i].count?.toDouble(),
                      label: model.timeline[i].day,
                      incomplete: model.timeline[i].availability ==
                          DayAvailability.incomplete,
                    ),
                ],
              ),
            ],
            unit: 'events',
            kind: TimeChartKind.bars,
          ),
        ),
        const SizedBox(height: 24),
        CoverageCalendar(observations: model.timeline),
        const SizedBox(height: 16),
        if (model.missingDays.isNotEmpty)
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Missing: ${model.missingDays.join(', ')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'No missing days in selected interval',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        StudioTable(
          columns: const [
            StudioColumn('Day', width: 140),
            StudioColumn('Events', width: 120, numeric: true),
            StudioColumn('Last updated', width: 180),
            StudioColumn('Status', width: 160),
          ],
          rows: [
            for (final obs in reversedTimeline)
              StudioRow([
                KeyedSubtree(
                  key: ValueKey('health-timeline-day:${obs.day}'),
                  child: StudioTextCell(obs.day),
                ),
                KeyedSubtree(
                  key: ValueKey('health-timeline-count:${obs.day}'),
                  child: StudioTextCell(
                    obs.count != null ? '${obs.count}' : '--',
                    numeric: true,
                  ),
                ),
                KeyedSubtree(
                  key: ValueKey('health-timeline-update:${obs.day}'),
                  child: StudioTextCell(
                    obs.updatedAt != null
                        ? _formatDateTime(obs.updatedAt!.toLocal())
                        : 'Unknown',
                  ),
                ),
                KeyedSubtree(
                  key: ValueKey('health-timeline-status:${obs.day}'),
                  child: StudioTextCell(_statusLabel(obs.availability)),
                ),
              ]),
          ],
        ),
      ],
    );
  }

  Widget _buildDataView(DataHealthViewModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final obs in model.timeline)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(obs.day),
                Text(
                  obs.count != null ? '${obs.count} events' : 'Unavailable',
                ),
              ],
            ),
          ),
      ],
    );
  }
}
