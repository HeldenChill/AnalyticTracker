import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Global filters: date presets, platform, version, refresh.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key, required this.onRefresh});
  final VoidCallback onRefresh;

  static const _presets = [7, 14, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final notifier = ref.read(filtersProvider.notifier);
    final options = ref.watch(filterOptionsProvider).valueOrNull ??
        const FilterOptions(platforms: [], versions: []);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PopupMenuButton<int>(
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
                      initialDateRange: DateTimeRange(start: DateTime.parse(f.from), end: DateTime.parse(f.to)),
                    );
                    if (picked != null) {
                      notifier.setRange(formatDay(picked.start), formatDay(picked.end));
                    }
                  },
                  itemBuilder: (_) => [
                    for (final d in _presets) PopupMenuItem(value: d, child: Text('Last $d days')),
                    const PopupMenuItem(value: 0, child: Text('Custom…')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.date_range, size: 18),
                      const SizedBox(width: 6),
                      Text('${f.from} → ${f.to}'),
                      const Icon(Icons.arrow_drop_down),
                    ]),
                  ),
                ),
                _OptionDropdown(
                  label: 'Platform',
                  value: f.platform,
                  options: options.platforms,
                  onChanged: notifier.setPlatform,
                ),
                _OptionDropdown(
                  label: 'Version',
                  value: f.version,
                  options: options.versions,
                  onChanged: notifier.setVersion,
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: onRefresh),
        ],
      ),
    );
  }
}

class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      // Keep an active filter visible even before /filters loads (or if it lacks it).
      value: value,
      items: [
        DropdownMenuItem<String?>(value: null, child: Text('$label: All')),
        if (value != null && !options.contains(value))
          DropdownMenuItem<String?>(value: value, child: Text(value!)),
        for (final o in options) DropdownMenuItem<String?>(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }
}
