import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

/// Last 30 days ending today (local calendar dates).
DateTimeRange defaultRange() {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, now.day - 29),
    end: DateTime(now.year, now.month, now.day),
  );
}

class RangeBar extends StatelessWidget {
  const RangeBar({super.key, required this.range, required this.onChanged});
  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.date_range),
      label: Text('${formatDay(range.start)} → ${formatDay(range.end)}'),
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime(now.year, now.month, now.day),
          initialDateRange: range,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
