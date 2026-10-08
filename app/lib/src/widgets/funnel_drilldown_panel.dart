import 'dart:convert';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/analytics_tokens.dart';

class FunnelDrilldownPanel extends ConsumerStatefulWidget {
  const FunnelDrilldownPanel({
    super.key,
    required this.def,
    required this.filters,
    required this.step,
    this.initialOutcome = FunnelPlayerOutcome.dropped,
    this.breakdown,
    this.segment,
    required this.onClose,
  });

  final FunnelDef def;
  final Filters filters;
  final int step;
  final FunnelPlayerOutcome initialOutcome;
  final FunnelBreakdown? breakdown;
  final String? segment;
  final VoidCallback onClose;

  @override
  ConsumerState<FunnelDrilldownPanel> createState() => _FunnelDrilldownPanelState();
}

class _FunnelDrilldownPanelState extends ConsumerState<FunnelDrilldownPanel> {
  late FunnelPlayerOutcome _outcome;
  FunnelPlayerItem? _selectedPlayer;

  @override
  void initState() {
    super.initState();
    _outcome = widget.initialOutcome;
  }

  @override
  void didUpdateWidget(FunnelDrilldownPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step || oldWidget.segment != widget.segment) {
      _selectedPlayer = null;
    }
  }

  String _formatTs(int micros) {
    final dt = DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
    return dt.toIso8601String().substring(0, 19).replaceAll('T', ' ');
  }

  Future<void> _copyCsv(List<FunnelPlayerItem> players) async {
    final csv = toCsv([
      'User ID',
      'Entry time (UTC)',
      'Reached step',
      'Last event time (UTC)',
    ], [
      for (final p in players)
        [
          p.uid,
          _formatTs(p.entryTs),
          p.reached,
          _formatTs(p.lastTs),
        ],
    ]);
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied CSV to clipboard')),
      );
    }
  }

  Future<void> _copyUid(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied User ID to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final stepIndex = widget.step - 1;
    final stepName = stepIndex < widget.def.steps.length
        ? widget.def.steps[stepIndex].event
        : 'Step ${widget.step}';

    return Container(
      width: 440,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: tokens.grid)),
      ),
      child: Material(
        color: theme.cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${widget.step}: $stepName',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.segment != null)
                        Text(
                          'Segment: ${widget.segment}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Close panel',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content: Player Timeline OR Player List
          Expanded(
            child: _selectedPlayer != null
                ? _buildTimelineView(theme, tokens)
                : _buildPlayerListView(theme, tokens),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPlayerListView(ThemeData theme, AnalyticsTokens tokens) {
    final q = (
      def: widget.def,
      filters: widget.filters,
      step: widget.step,
      outcome: _outcome,
      breakdown: widget.breakdown,
      segment: widget.segment,
      limit: 100,
    );
    final asyncPlayers = ref.watch(funnelPlayersProvider(q));

    return Column(
      children: [
        // Tabs & Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<FunnelPlayerOutcome>(
                  segments: const [
                    ButtonSegment(
                      value: FunnelPlayerOutcome.dropped,
                      label: Text('Dropped'),
                    ),
                    ButtonSegment(
                      value: FunnelPlayerOutcome.converted,
                      label: Text('Converted'),
                    ),
                  ],
                  selected: {_outcome},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _outcome = s.first),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: asyncPlayers.valueOrNull == null
                    ? null
                    : () => _copyCsv(asyncPlayers.value!.players),
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('CSV'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List
        Expanded(
          child: asyncPlayers.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (res) {
              if (res.players.isEmpty) {
                return Center(
                  child: Text(
                    'No players ${_outcome == FunnelPlayerOutcome.dropped ? 'dropped' : 'converted'} at this step',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return ListView.separated(
                itemCount: res.players.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = res.players[i];
                  final shortUid = p.uid.length > 20
                      ? '${p.uid.substring(0, 10)}...${p.uid.substring(p.uid.length - 6)}'
                      : p.uid;
                  return ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Tooltip(
                            message: p.uid,
                            child: Text(
                              shortUid,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 14),
                          onPressed: () => _copyUid(p.uid),
                          tooltip: 'Copy user ID',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Entered: ${_formatTs(p.entryTs)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tokens.grid,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Reached step ${p.reached}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => setState(() => _selectedPlayer = p),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineView(ThemeData theme, AnalyticsTokens tokens) {
    final player = _selectedPlayer!;
    // 1h before entry, 24h after last matched step
    final fromTs = player.entryTs - 3600000000;
    final toTs = player.lastTs + 86400000000;

    final q = (
      uid: player.uid,
      fromTs: fromTs,
      toTs: toTs,
      includeTest: widget.filters.includeTest,
      limit: 300,
    );
    final asyncEvents = ref.watch(playerEventsProvider(q));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedPlayer = null),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to list'),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => _copyUid(player.uid),
                tooltip: 'Copy user ID',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Timeline', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                '${_formatTs(fromTs)} → ${_formatTs(toTs)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),

        // Events
        Expanded(
          child: asyncEvents.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (events) {
              if (events.isEmpty) {
                return Center(
                  child: Text('No events found for this player', style: theme.textTheme.bodyMedium),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: events.length,
                itemBuilder: (context, i) {
                  final ev = events[i];
                  final matchedStepIdx = player.stepTs.indexOf(ev.ts);
                  final isStepMatch = matchedStepIdx != -1;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isStepMatch
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(tokens.radius / 2),
                      border: Border.all(
                        color: isStepMatch ? theme.colorScheme.primary : tokens.grid,
                        width: isStepMatch ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatTs(ev.ts),
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const Spacer(),
                            if (isStepMatch)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Step ${matchedStepIdx + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ev.event,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isStepMatch ? theme.colorScheme.primary : null,
                          ),
                        ),
                        if (ev.params.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            jsonEncode(ev.params),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
