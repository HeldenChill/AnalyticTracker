import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../providers.dart';
import '../theme/analytics_tokens.dart';
import '../widgets/error_retry.dart';
import '../widgets/format.dart';
import '../widgets/funnel_chart.dart';
import '../widgets/funnel_editor.dart';
import '../widgets/funnel_segment_table.dart';
import '../widgets/funnel_step_table.dart';
import '../widgets/funnel_trend_view.dart';

class FunnelPage extends ConsumerStatefulWidget {
  const FunnelPage({super.key});
  @override
  ConsumerState<FunnelPage> createState() => _FunnelPageState();
}

class _FunnelPageState extends ConsumerState<FunnelPage> {
  int? _selectedId;
  FunnelDef? _draft;

  SavedFunnel? _selected(List<SavedFunnel> list) {
    for (final s in list) {
      if (s.id == _selectedId) return s;
    }
    return list.isEmpty ? null : list.first;
  }

  Future<String?> _persist(int? id, FunnelDef def) async {
    final api = ref.read(apiClientProvider);
    try {
      final saved = id == null ? await api.createFunnel(def) : await api.updateFunnel(id, def);
      ref.invalidate(savedFunnelsProvider);
      if (mounted) {
        setState(() {
          _selectedId = saved.id;
          _draft = null;
        });
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> _openEditor({SavedFunnel? editing, FunnelDef? initial}) async {
    final outcome = await showFunnelEditor(context, initial: initial, onSave: (def) => _persist(editing?.id, def));
    if (outcome != null && !outcome.saved && mounted) setState(() => _draft = outcome.def);
  }

  Future<void> _delete(SavedFunnel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${s.name}"?'),
        content: const Text('Everyone on the team loses this saved funnel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deleteFunnel(s.id);
      ref.invalidate(savedFunnelsProvider);
      if (mounted) setState(() => _selectedId = null);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ref.watch(savedFunnelsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(savedFunnelsProvider)),
          data: (list) {
            final selected = _selected(list);
            final def = _draft ?? selected?.def;
            if (def == null) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('No saved funnels yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Build a funnel once and the whole team can open it.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first funnel'),
                  ),
                ]),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (selected != null)
                      DropdownButton<int>(
                        value: selected.id,
                        items: [for (final s in list) DropdownMenuItem(value: s.id, child: Text(s.name))],
                        onChanged: (v) => setState(() {
                          _selectedId = v;
                          _draft = null;
                        }),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text('New funnel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openEditor(editing: _draft == null ? selected : null, initial: def),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    if (_draft == null && selected != null)
                      OutlinedButton.icon(
                        onPressed: () => _delete(selected),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    if (_draft != null) const Chip(label: Text('Unsaved draft')),
                  ],
                ),
                const SizedBox(height: 16),
                _FunnelResultView(def: def),
              ],
            );
          },
        );
  }
}

enum _FunnelViewMode { steps, trend }

class _FunnelResultView extends ConsumerStatefulWidget {
  const _FunnelResultView({required this.def});
  final FunnelDef def;

  @override
  ConsumerState<_FunnelResultView> createState() => _FunnelResultViewState();
}

class _FunnelResultViewState extends ConsumerState<_FunnelResultView> {
  _FunnelViewMode _viewMode = _FunnelViewMode.steps;
  FunnelInterval _interval = FunnelInterval.day;
  FunnelBreakdownBy? _breakdownBy;
  String? _paramKey;
  String? _userPropKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final filters = ref.watch(filtersProvider);

    FunnelBreakdown? breakdown;
    if (_breakdownBy == FunnelBreakdownBy.platform) {
      breakdown = const FunnelBreakdown(by: FunnelBreakdownBy.platform);
    } else if (_breakdownBy == FunnelBreakdownBy.version) {
      breakdown = const FunnelBreakdown(by: FunnelBreakdownBy.version);
    } else if (_breakdownBy == FunnelBreakdownBy.param && _paramKey != null) {
      breakdown = FunnelBreakdown(by: FunnelBreakdownBy.param, key: _paramKey);
    } else if (_breakdownBy == FunnelBreakdownBy.userProp && _userPropKey != null) {
      breakdown = FunnelBreakdown(by: FunnelBreakdownBy.userProp, key: _userPropKey);
    }

    final q = (
      def: widget.def,
      filters: filters,
      breakdown: breakdown,
      interval: _viewMode == _FunnelViewMode.trend ? _interval : null,
    );
    return ref.watch(funnelResultProvider(q)).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(funnelResultProvider(q))),
          data: (r) {
            final first = r.steps.isEmpty ? 0 : r.steps.first.players;
            final drop = r.biggestDropIndex;

            final step1Event = widget.def.steps.isEmpty ? null : widget.def.steps.first.event;
            final step1ParamKeys = step1Event == null
                ? const <String>[]
                : ref.watch(paramKeysProvider((event: step1Event, filters: filters))).valueOrNull ?? const [];
            final userPropKeys = ref.watch(userPropKeysProvider(filters)).valueOrNull ?? const [];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(widget.def.name, style: theme.textTheme.titleLarge),
                        Chip(label: Text(funnelWindowLabel(widget.def.windowMinutes))),
                        Chip(label: Text(widget.def.order.label)),
                        const SizedBox(width: 8),
                        SegmentedButton<_FunnelViewMode>(
                          segments: const [
                            ButtonSegment(value: _FunnelViewMode.steps, label: Text('Steps')),
                            ButtonSegment(value: _FunnelViewMode.trend, label: Text('Trend')),
                          ],
                          selected: {_viewMode},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                        ),
                      ],
                    ),
                    if (_viewMode == _FunnelViewMode.trend) ...[
                      const SizedBox(height: 16),
                      FunnelTrendView(
                        result: r,
                        interval: _interval,
                        onIntervalChanged: (i) => setState(() => _interval = i),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      // Breakdown selector row
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Breakdown:'),
                          DropdownButton<FunnelBreakdownBy?>(
                            value: _breakdownBy,
                            hint: const Text('None'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('None')),
                              for (final b in FunnelBreakdownBy.values)
                                DropdownMenuItem(value: b, child: Text(b.label)),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _breakdownBy = val;
                                _paramKey = null;
                                _userPropKey = null;
                              });
                            },
                          ),
                          if (_breakdownBy == FunnelBreakdownBy.param) ...[
                            DropdownButton<String>(
                              value: _paramKey,
                              hint: const Text('Pick param'),
                              items: [
                                for (final k in step1ParamKeys)
                                  DropdownMenuItem(value: k, child: Text(k)),
                              ],
                              onChanged: (k) => setState(() => _paramKey = k),
                            ),
                          ],
                          if (_breakdownBy == FunnelBreakdownBy.userProp) ...[
                            DropdownButton<String>(
                              value: _userPropKey,
                              hint: const Text('Pick user property'),
                              items: [
                                for (final k in userPropKeys)
                                  DropdownMenuItem(value: k, child: Text(k)),
                              ],
                              onChanged: (k) => setState(() => _userPropKey = k),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(spacing: 36, runSpacing: 12, children: [
                        _Stat(value: fmtPct(r.totalConversion), label: 'Total conversion'),
                        _Stat(value: '$first', label: 'Players entered'),
                        _Stat(
                          value: drop == null ? '—' : '−${fmtPct(1 - (r.steps[drop].fromPrevious ?? 1))}',
                          label: drop == null ? 'Biggest drop' : 'Biggest drop: step $drop → ${drop + 1}',
                          color: drop == null ? null : tokens.bad,
                        ),
                      ]),
                      if (first == 0)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('No players reached step 1 in this range'),
                        ),
                      const SizedBox(height: 16),
                      FunnelChart(result: r),
                      const SizedBox(height: 16),
                      if (r.segments.isNotEmpty) ...[
                        Text('Segments', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: FunnelSegmentTable(result: r),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('Steps', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: FunnelStepTable(result: r, order: widget.def.order),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color)),
      Text(label, style: theme.textTheme.labelMedium),
    ]);
  }
}
