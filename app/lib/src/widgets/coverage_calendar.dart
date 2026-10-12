import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../view_models/storage_observations.dart';

class CoverageCalendar extends StatefulWidget {
  const CoverageCalendar({
    super.key,
    required this.observations,
  });

  final List<StoredObservation> observations;

  @override
  State<CoverageCalendar> createState() => _CoverageCalendarState();
}

class _CoverageCalendarState extends State<CoverageCalendar> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, GlobalKey<TooltipState>> _tooltipKeys = {};

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
  }

  @override
  void didUpdateWidget(covariant CoverageCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocusNodes();
  }

  void _syncFocusNodes() {
    final currentDays = {for (final o in widget.observations) o.day};
    final obsolete = _focusNodes.keys.where((d) => !currentDays.contains(d)).toList();
    for (final day in obsolete) {
      _focusNodes[day]?.dispose();
      _focusNodes.remove(day);
      _tooltipKeys.remove(day);
    }
    for (final obs in widget.observations) {
      _focusNodes.putIfAbsent(obs.day, () => FocusNode());
      _tooltipKeys.putIfAbsent(obs.day, () => GlobalKey<TooltipState>());
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    _tooltipKeys.clear();
    _scrollController.dispose();
    super.dispose();
  }

  static String _tooltipFor(StoredObservation obs) {
    switch (obs.availability) {
      case DayAvailability.stored:
        return '${obs.day}: stored, ${obs.count ?? 0} events';
      case DayAvailability.missing:
        return '${obs.day}: missing';
      case DayAvailability.incomplete:
        return obs.count != null
            ? '${obs.day}: may be incomplete, ${obs.count} events'
            : '${obs.day}: may be incomplete, not stored';
      case DayAvailability.future:
        return '${obs.day}: future';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.observations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'No dates in this interval',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final isBold = MediaQuery.boldTextOf(context);
    final baseTextStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final effectiveStyle = baseTextStyle.copyWith(
      fontWeight: isBold ? FontWeight.bold : baseTextStyle.fontWeight,
    );

    double maxTextWidth = 0;
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (final label in [...weekdayLabels, '31']) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: effectiveStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      if (tp.width > maxTextWidth) maxTextWidth = tp.width;
      tp.dispose();
    }
    final minimumCellWidth = math.max(34.0, maxTextWidth + 12.0);

    final numTp = TextPainter(
      text: TextSpan(text: '31', style: effectiveStyle),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
    )..layout();
    final numHeight = numTp.height;
    numTp.dispose();
    final cellHeight = math.max(48.0, numHeight + 12.0 + 4.0 + 12.0);

    final grouped = <String, List<StoredObservation>>{};
    for (final obs in widget.observations) {
      final month = obs.day.substring(0, 7);
      grouped.putIfAbsent(month, () => []).add(obs);
    }

    final maxMeasuredCount = widget.observations
        .map((o) => o.count ?? 0)
        .fold<int>(0, math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final gridMinWidth = 7 * minimumCellWidth + 6 * 4.0;
        final totalWidth = math.max(availableWidth, gridMinWidth);
        final needsScroll = totalWidth > availableWidth;

        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in grouped.entries)
              _buildMonthSection(
                context,
                monthKey: entry.key,
                monthObs: entry.value,
                totalWidth: totalWidth,
                minimumCellWidth: minimumCellWidth,
                cellHeight: cellHeight,
                maxMeasuredCount: maxMeasuredCount,
              ),
          ],
        );

        if (needsScroll) {
          content = Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: content,
              ),
            ),
          );
        }

        return content;
      },
    );
  }

  Widget _buildMonthSection(
    BuildContext context, {
    required String monthKey,
    required List<StoredObservation> monthObs,
    required double totalWidth,
    required double minimumCellWidth,
    required double cellHeight,
    required int maxMeasuredCount,
  }) {
    final theme = Theme.of(context);
    final firstDay = monthObs.first.day;
    final firstWeekday = DateTime.parse('${firstDay}T00:00:00Z').weekday;
    final leadingBlanks = firstWeekday - 1;
    final trailingBlanks = (7 - (leadingBlanks + monthObs.length) % 7) % 7;
    final totalCells = leadingBlanks + monthObs.length + trailingBlanks;

    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      key: ValueKey('coverage-month:$monthKey'),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              monthKey,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              for (var w = 1; w <= 7; w++) ...[
                if (w > 1) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    key: ValueKey('coverage-weekday:$monthKey:$w'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    child: Text(
                      weekdayLabels[w - 1],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              mainAxisExtent: cellHeight,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < leadingBlanks || index >= leadingBlanks + monthObs.length) {
                return const SizedBox.shrink();
              }
              final obsIndex = index - leadingBlanks;
              final obs = monthObs[obsIndex];
              return _buildCell(
                context,
                obs: obs,
                maxMeasuredCount: maxMeasuredCount,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context, {
    required StoredObservation obs,
    required int maxMeasuredCount,
  }) {
    final theme = Theme.of(context);
    final focusNode = _focusNodes[obs.day]!;
    final tooltipKey = _tooltipKeys[obs.day]!;
    final tooltipText = _tooltipFor(obs);
    final dayNum = int.parse(obs.day.substring(8)).toString();

    Color bgColor;
    Border border;
    IconData statusIcon;
    Color iconColor;

    switch (obs.availability) {
      case DayAvailability.stored:
        final count = obs.count ?? 0;
        if (count == 0) {
          bgColor = theme.colorScheme.surface;
          border = Border.all(color: theme.colorScheme.primary, width: 2);
          statusIcon = Icons.crop_square;
          iconColor = theme.colorScheme.primary;
        } else {
          final intensity = maxMeasuredCount > 0
              ? (count / maxMeasuredCount).clamp(0.15, 1.0)
              : 0.5;
          bgColor = theme.colorScheme.primaryContainer.withValues(alpha: intensity);
          border = Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5));
          statusIcon = Icons.check_circle_outline;
          iconColor = theme.colorScheme.onPrimaryContainer;
        }
        break;
      case DayAvailability.missing:
        bgColor = theme.colorScheme.errorContainer.withValues(alpha: 0.35);
        border = Border.all(color: theme.colorScheme.error, width: 1.5);
        statusIcon = Icons.remove_circle_outline;
        iconColor = theme.colorScheme.error;
        break;
      case DayAvailability.incomplete:
        bgColor = theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4);
        border = Border.all(color: theme.colorScheme.tertiary, width: 1.5);
        statusIcon = Icons.timelapse;
        iconColor = theme.colorScheme.tertiary;
        break;
      case DayAvailability.future:
        bgColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
        border = Border.all(color: theme.colorScheme.outlineVariant);
        statusIcon = Icons.schedule;
        iconColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
        break;
    }

    return FocusableActionDetector(
      focusNode: focusNode,
      onFocusChange: (focused) {
        if (focused) {
          tooltipKey.currentState?.ensureTooltipVisible();
        }
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _NavIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _NavIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _NavIntent(-7),
        SingleActivator(LogicalKeyboardKey.arrowDown): _NavIntent(7),
        SingleActivator(LogicalKeyboardKey.enter): _ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): _ActivateIntent(),
      },
      actions: {
        _NavIntent: CallbackAction<_NavIntent>(
          onInvoke: (intent) {
            final idx = widget.observations.indexOf(obs);
            final targetIdx = idx + intent.delta;
            if (targetIdx >= 0 && targetIdx < widget.observations.length) {
              final targetDay = widget.observations[targetIdx].day;
              _focusNodes[targetDay]?.requestFocus();
            }
            return null;
          },
        ),
        _ActivateIntent: CallbackAction<_ActivateIntent>(
          onInvoke: (_) {
            tooltipKey.currentState?.ensureTooltipVisible();
            return null;
          },
        ),
      },
      child: Semantics(
        label: tooltipText,
        button: false,
        focusable: true,
        focused: focusNode.hasFocus,
        child: Tooltip(
          key: tooltipKey,
          message: tooltipText,
          child: Container(
            key: ValueKey('coverage-day:${obs.day}'),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              border: border,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayNum,
                  key: ValueKey('coverage-number:${obs.day}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(statusIcon, size: 12, color: iconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIntent extends Intent {
  const _NavIntent(this.delta);
  final int delta;
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}
