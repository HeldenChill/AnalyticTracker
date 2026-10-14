import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/analytics_tokens.dart';
import 'filter_trigger.dart';

/// Global filters: date presets, platform, version, refresh.
class FilterBar extends ConsumerWidget {
  const FilterBar({
    super.key,
    required this.onRefresh,
    this.storageScope = false,
    this.refreshing = false,
  });

  final VoidCallback onRefresh;
  final bool storageScope;
  final bool refreshing;

  static const _presets = [7, 14, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final borderRadius =
        BorderRadius.circular((tokens.radius - 4).clamp(4.0, 24.0));
    final f = ref.watch(filtersProvider);
    final notifier = ref.read(filtersProvider.notifier);
    final options = ref.watch(filterOptionsProvider).valueOrNull ??
        const FilterOptions(platforms: [], versions: []);

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _FilterField(
                  label: 'Date range',
                  child: PopupMenuButton<int>(
                    key: const ValueKey('filter-date-range'),
                    tooltip: 'Date range',
                    borderRadius: borderRadius,
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 4),
                    shape: RoundedRectangleBorder(borderRadius: borderRadius),
                    onSelected: (days) async {
                      if (days > 0) {
                        notifier.applyPreset(days);
                        return;
                      }
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(now.year, now.month, now.day),
                        initialDateRange: DateTimeRange(
                          start: DateTime.parse(f.from),
                          end: DateTime.parse(f.to),
                        ),
                      );
                      if (picked != null && context.mounted) {
                        notifier.setRange(
                          formatDay(picked.start),
                          formatDay(picked.end),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      for (final d in _presets)
                        PopupMenuItem(value: d, child: Text('Last $d days')),
                      const PopupMenuItem(value: 0, child: Text('Custom…')),
                    ],
                    child: FilterTrigger(
                      borderRadius: borderRadius,
                      maxWidth: maxW,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${f.from} → ${f.to}',
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
                _FilterField(
                  label: 'Platform',
                  child: _OptionDropdown(
                    dropdownKey: const ValueKey('filter-platform'),
                    allLabel: 'All platforms',
                    value: f.platform,
                    options: options.platforms,
                    onChanged: storageScope ? null : notifier.setPlatform,
                    borderRadius: borderRadius,
                    maxWidth: maxW,
                  ),
                ),
                _FilterField(
                  label: 'Version',
                  child: _OptionDropdown(
                    dropdownKey: const ValueKey('filter-version'),
                    allLabel: 'All versions',
                    value: f.version,
                    options: options.versions,
                    onChanged: storageScope ? null : notifier.setVersion,
                    borderRadius: borderRadius,
                    maxWidth: maxW,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: Alignment.center,
                    widthFactor: 1.0,
                    child: FilterChip(
                      key: const ValueKey('filter-test-devices'),
                      label: const Text('Test devices'),
                      tooltip:
                          'Include events sent from Firebase DebugView test devices',
                      selected: f.includeTest,
                      onSelected: storageScope ? null : notifier.setIncludeTest,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Refresh',
                  child: Semantics(
                    label: refreshing ? 'Refreshing data' : null,
                    child: OutlinedButton.icon(
                      key: const ValueKey('refresh-button'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: borderRadius,
                        ),
                        side:
                            BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      onPressed: refreshing ? null : onRefresh,
                      icon: refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(refreshing ? 'Refreshing' : 'Refresh'),
                    ),
                  ),
                ),
                if (storageScope)
                  SizedBox(
                    width: maxW,
                    child: Text(
                      'Storage scope: platform/version/test filters do not apply',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          child,
        ],
      );
}

/// Non-null wrapper so popup dismissal (which yields null from onSelected) is
/// never confused with the user explicitly choosing "All" (null value).
class _OptionChoice {
  const _OptionChoice(this.value);
  final String? value;
}

class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({
    this.dropdownKey,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.borderRadius,
    required this.maxWidth,
  });

  final Key? dropdownKey;
  final String allLabel;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;
  final BorderRadius borderRadius;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = maxWidth < 240 ? maxWidth : 160.0;

    final choices = <_OptionChoice>[
      const _OptionChoice(null),
      if (value != null && !options.contains(value)) _OptionChoice(value),
      for (final v in options.toSet()) _OptionChoice(v),
    ];

    final displayLabel = value ?? allLabel;

    return PopupMenuButton<_OptionChoice>(
      key: dropdownKey,
      enabled: onChanged != null,
      borderRadius: borderRadius,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      tooltip: displayLabel,
      onSelected: (choice) => onChanged?.call(choice.value),
      itemBuilder: (_) => [
        for (final choice in choices)
          PopupMenuItem<_OptionChoice>(
            value: choice,
            child: Text(
              choice.value ?? allLabel,
              softWrap: true,
            ),
          ),
      ],
      child: FilterTrigger(
        borderRadius: borderRadius,
        maxWidth: width,
        minWidth: 120,
        // No tooltip here: PopupMenuButton.tooltip already creates one at this
        // location. A second Tooltip widget would cause find.byTooltip() to
        // match two widgets and break tests that assert findsOneWidget.
        enabled: onChanged != null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
