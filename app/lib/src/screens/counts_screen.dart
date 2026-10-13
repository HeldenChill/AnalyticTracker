import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/format.dart';
import '../providers.dart';
import '../state/events_explorer.dart';
import '../state/navigation.dart';
import '../state/refresh.dart';
import '../view_models/events_view_model.dart';
import '../widgets/charts/chart_models.dart';
import '../widgets/charts/ranked_bar_chart.dart';
import '../widgets/charts/time_series_chart.dart';
import '../widgets/event_detail_panel.dart';
import '../widgets/studio_async_panel.dart';
import '../widgets/studio_layout.dart';
import '../widgets/studio_table.dart';

class CountsScreen extends ConsumerStatefulWidget {
  const CountsScreen({
    super.key,
    this.onExploreParameters,
    this.now,
  });

  final ValueChanged<String>? onExploreParameters;
  final DateTime Function()? now;

  @override
  ConsumerState<CountsScreen> createState() => _CountsScreenState();
}

class _CountsScreenState extends ConsumerState<CountsScreen> {
  bool _compare = true;
  TimeChartKind _chartKind = TimeChartKind.line;
  String _search = '';
  int _sortColumnIndex = 1;
  bool _sortAscending = false;

  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  int _compareChanges(EventChange a, EventChange b, bool ascending) {
    if (a.kind == ChangeKind.unavailable && b.kind == ChangeKind.unavailable) return 0;
    if (a.kind == ChangeKind.unavailable) return 1;
    if (b.kind == ChangeKind.unavailable) return -1;

    int cmp;
    if (a.kind == ChangeKind.newActivity && b.kind == ChangeKind.newActivity) {
      cmp = 0;
    } else if (a.kind == ChangeKind.newActivity) {
      cmp = 1;
    } else if (b.kind == ChangeKind.newActivity) {
      cmp = -1;
    } else {
      final fA = a.fraction ?? 0.0;
      final fB = b.fraction ?? 0.0;
      cmp = fA.compareTo(fB);
    }
    return ascending ? cmp : -cmp;
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);
    final q = (filters: f, compare: _compare);

    return ActiveRequestScope(
      page: AppPage.events,
      queryKey: (baseUrl, q),
      reload: () async {
        try {
          final payload = await ref.refresh(eventsExplorerProvider(q).future);
          final warnings = payload.previousError != null
              ? ['Comparison data unavailable: ${payload.previousError}']
              : const <String>[];
          return RefreshResult(warnings: warnings);
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: StudioAsyncPanel<EventsPayload>(
        queryKey: (baseUrl, q),
        value: ref.watch(eventsExplorerProvider(q)),
        onRetry: () => ref.invalidate(eventsExplorerProvider(q)),
        builder: (payload) {
          final model = buildEventSummary(
            current: payload.current,
            previous: payload.previous,
            stored: payload.days,
            filters: f,
            now: (widget.now ?? DateTime.now)(),
          );
          return _buildEventsContent(model, payload.previousError, f, q);
        },
      ),
    );
  }

  Widget _buildEventsContent(
    EventSummary model,
    Object? previousError,
    Filters f,
    EventsQuery q,
  ) {
    final theme = Theme.of(context);
    final selectedEvent = ref.watch(selectedEventProvider);

    var filteredRows = model.rows;
    if (_search.trim().isNotEmpty) {
      final query = _search.trim().toLowerCase();
      filteredRows = [
        for (final r in filteredRows)
          if (r.name.toLowerCase().contains(query)) r,
      ];
    }

    // Clear stale selection if selected row is not in current data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentSelection = ref.read(selectedEventProvider);
      if (currentSelection != null &&
          !model.rows.any((r) => r.name == currentSelection)) {
        ref.read(selectedEventProvider.notifier).state = null;
      }
    });

    final sortedRows = List<EventRowSummary>.from(filteredRows);
    sortedRows.sort((a, b) {
      int c = 0;
      switch (_sortColumnIndex) {
        case 0:
          c = a.name.compareTo(b.name);
          return _sortAscending ? c : -c;
        case 1:
          c = a.current.compareTo(b.current);
          break;
        case 2:
          c = a.share.compareTo(b.share);
          break;
        case 3:
          final changeCmp = _compareChanges(a.change, b.change, _sortAscending);
          if (changeCmp != 0) return changeCmp;
          return a.name.compareTo(b.name);
      }
      final primary = _sortAscending ? c : -c;
      if (primary != 0) return primary;
      return a.name.compareTo(b.name);
    });

    final selectedRow = selectedEvent != null
        ? model.rows.where((r) => r.name == selectedEvent).firstOrNull
        : null;

    final totalChange = eventChange(
      model.total,
      model.previousTotal,
      comparable: model.comparisonAvailable,
    );

    String totalDetail;
    Widget? totalBadge;
    if (!_compare) {
      totalDetail = 'Comparison off';
    } else if (previousError != null) {
      totalDetail = 'Comparison unavailable';
    } else if (!model.comparisonAvailable) {
      if (model.missingDays.isNotEmpty) {
        totalDetail = 'Missing days: ${model.missingDays.join(", ")}';
      } else {
        totalDetail = 'Incomplete observation range';
      }
    } else {
      switch (totalChange.kind) {
        case ChangeKind.percent:
          final fr = totalChange.fraction ?? 0.0;
          final sign = fr > 0 ? '+' : '';
          final text = '$sign${(fr * 100).toStringAsFixed(1)}%';
          totalDetail = 'vs previous period (${fmtCount(model.previousTotal ?? 0)})';
          totalBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (fr >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fr >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
          break;
        case ChangeKind.newActivity:
          totalDetail = 'New activity';
          totalBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'New',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
          break;
        case ChangeKind.unchanged:
          totalDetail = 'Unchanged';
          break;
        case ChangeKind.unavailable:
          totalDetail = 'Comparison unavailable';
          break;
      }
    }

    String tableEmptyMessage;
    if (_search.trim().isNotEmpty) {
      tableEmptyMessage = 'No event names match this search.';
    } else if (model.storedDayCount == 0) {
      tableEmptyMessage = 'No stored observations for this date range.';
    } else {
      tableEmptyMessage = 'No event occurrences in this period.';
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        StudioHeading(
          title: 'Events',
          subtitle: 'Event volume, mix and trends across selected gameplay filters.',
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Compare'),
                const SizedBox(width: 8),
                Switch(
                  value: _compare,
                  onChanged: (val) => setState(() => _compare = val),
                ),
              ],
            ),
            SegmentedButton<TimeChartKind>(
              segments: const [
                ButtonSegment(value: TimeChartKind.line, label: Text('Line')),
                ButtonSegment(value: TimeChartKind.area, label: Text('Area')),
                ButtonSegment(value: TimeChartKind.bars, label: Text('Bars')),
              ],
              selected: {_chartKind},
              onSelectionChanged: (set) => setState(() => _chartKind = set.first),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (previousError != null && _compare) ...[
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Comparison unavailable: unable to load previous period counts.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(eventsExplorerProvider(q)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
        StudioGrid(
          minChildWidth: 200,
          maxColumns: 4,
          children: [
            StudioMetric(
              key: const ValueKey('events-total-occurrences'),
              title: 'Total occurrences',
              value: fmtCount(model.total),
              detail: totalDetail,
              badge: totalBadge,
            ),
            StudioMetric(
              key: const ValueKey('events-distinct-types'),
              title: 'Event types',
              value: '${model.distinctNames}',
              detail: 'Active event names',
            ),
            StudioMetric(
              key: const ValueKey('events-average-day'),
              title: 'Average per stored day',
              value: model.averagePerStoredDay != null
                  ? model.averagePerStoredDay!.toStringAsFixed(1)
                  : '—',
              detail: 'Across ${model.storedDayCount} stored days',
            ),
            StudioMetric(
              key: const ValueKey('events-peak-day'),
              title: 'Peak stored day',
              value: model.peakDay != null
                  ? '${model.peakDay} (${fmtCount(model.peakCount ?? 0)})'
                  : '—',
              detail: 'Highest single day',
            ),
          ],
        ),
        const SizedBox(height: 20),
        StudioGrid(
          minChildWidth: 320,
          maxColumns: 2,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily occurrences trend',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TimeSeriesChart(
                      series: [
                        ChartSeries(
                          id: 'current',
                          label: 'Current period',
                          points: model.currentSeries,
                        ),
                        if (_compare && model.previousSeries.isNotEmpty)
                          ChartSeries(
                            id: 'previous',
                            label: 'Previous period',
                            points: model.previousSeries,
                          ),
                      ],
                      kind: _chartKind,
                      unit: 'occurrences',
                      plotHeight: 180,
                    ),
                  ],
                ),
              ),
            ),
            if (model.rows.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top events',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RankedBarChart(
                        values: [
                          for (final r in model.rows.take(10))
                            RankedValue(
                              r.name,
                              r.name,
                              r.current.toDouble(),
                              detail: '${(r.share * 100).toStringAsFixed(1)}%',
                            ),
                        ],
                        unit: 'occurrences',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All events',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        key: const ValueKey('events-search'),
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search events...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (val) => setState(() => _search = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StudioTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  emptyMessage: tableEmptyMessage,
                  columns: [
                    StudioColumn(
                      'Event name',
                      width: 260,
                      onSort: (col, asc) => _setSort(col, asc),
                    ),
                    StudioColumn(
                      'Occurrences',
                      width: 130,
                      numeric: true,
                      onSort: (col, asc) => _setSort(col, asc),
                    ),
                    StudioColumn(
                      'Share',
                      width: 100,
                      numeric: true,
                      onSort: (col, asc) => _setSort(col, asc),
                    ),
                    StudioColumn(
                      'Change',
                      width: 120,
                      numeric: true,
                      onSort: (col, asc) => _setSort(col, asc),
                    ),
                  ],
                  rows: [
                    for (final r in sortedRows)
                      StudioRow(
                        [
                          KeyedSubtree(
                            key: ValueKey('event-row-${r.name}'),
                            child: StudioTextCell(r.name, width: 260),
                          ),
                          StudioTextCell(fmtCount(r.current), numeric: true),
                          StudioTextCell(
                            '${(r.share * 100).toStringAsFixed(1)}%',
                            numeric: true,
                          ),
                          StudioTextCell(
                            _formatChange(r.change),
                            numeric: true,
                            style: TextStyle(
                              color: _changeColor(r.change, theme),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        key: ValueKey('event-row-${r.name}'),
                        selected: selectedEvent == r.name,
                        onSelectChanged: (_) {
                          ref.read(selectedEventProvider.notifier).state = r.name;
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (selectedRow != null) ...[
          EventDetailPanel(
            event: selectedRow,
            filters: f,
            onClose: () => ref.read(selectedEventProvider.notifier).state = null,
            onExploreParameters: widget.onExploreParameters,
          ),
        ],
      ],
    ),
    );
  }

  String _formatChange(EventChange change) {
    switch (change.kind) {
      case ChangeKind.percent:
        final f = change.fraction ?? 0.0;
        final sign = f > 0 ? '+' : '';
        return '$sign${(f * 100).toStringAsFixed(1)}%';
      case ChangeKind.newActivity:
        return 'New';
      case ChangeKind.unchanged:
        return '0.0%';
      case ChangeKind.unavailable:
        return '—';
    }
  }

  Color? _changeColor(EventChange change, ThemeData theme) {
    switch (change.kind) {
      case ChangeKind.percent:
        final f = change.fraction ?? 0.0;
        return f >= 0 ? Colors.green : Colors.red;
      case ChangeKind.newActivity:
        return Colors.blue;
      case ChangeKind.unchanged:
      case ChangeKind.unavailable:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
