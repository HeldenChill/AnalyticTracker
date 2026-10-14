import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/analytics_tokens.dart';

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
                    child: Container(
                      constraints: BoxConstraints(
                        minWidth: 160,
                        maxWidth: maxW,
                        minHeight: 44,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                        borderRadius: borderRadius,
                      ),
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
                    label: 'Platform',
                    value: f.platform,
                    options: options.platforms,
                    onChanged: storageScope ? null : notifier.setPlatform,
                    maxWidth: maxW,
                  ),
                ),
                _FilterField(
                  label: 'Version',
                  child: _OptionDropdown(
                    dropdownKey: const ValueKey('filter-version'),
                    label: 'Version',
                    value: f.version,
                    options: options.versions,
                    onChanged: storageScope ? null : notifier.setVersion,
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

class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({
    this.dropdownKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.maxWidth,
  });

  final Key? dropdownKey;
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final borderRadius =
        BorderRadius.circular((tokens.radius - 4).clamp(4.0, 24.0));

    final values = <String?>[
      null,
      if (value != null && !options.contains(value)) value,
      ...options.toSet(),
    ];
    String optionLabel(String? option) =>
        option ?? (label == 'Platform' ? 'All platforms' : 'All versions');
    final items = [
      for (final option in values)
        DropdownMenuItem<String?>(
          value: option,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(optionLabel(option), softWrap: true),
          ),
        ),
    ];

    final width = maxWidth < 240 ? maxWidth : 160.0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 120,
        maxWidth: width,
        minHeight: 44,
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            key: dropdownKey,
            value: value,
            isExpanded: true,
            isDense: true,
            itemHeight: null,
            selectedItemBuilder: (context) => [
              for (final option in values)
                Tooltip(
                  message: optionLabel(option),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(optionLabel(option),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
            ],
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
