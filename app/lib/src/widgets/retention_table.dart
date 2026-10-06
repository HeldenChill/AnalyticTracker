import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import 'format.dart';

/// Cohort table. A null cell (day not observable yet) is blank, never 0%.
class RetentionTable extends StatelessWidget {
  const RetentionTable({super.key, required this.data});
  final RetentionData data;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    Widget pctCell(double? rate) {
      if (rate == null) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: color.withValues(alpha: 0.08 + 0.6 * rate.clamp(0.0, 1.0)),
        child: Text(fmtPct(rate)),
      );
    }

    final totalSize = data.cohorts.fold<int>(0, (a, c) => a + c.size);
    return DataTable(
      columnSpacing: 18,
      columns: [
        const DataColumn(label: Text('Cohort (first_open)')),
        const DataColumn(label: Text('Players'), numeric: true),
        for (final o in data.offsets) DataColumn(label: Text('D$o')),
      ],
      rows: [
        for (final c in data.cohorts)
          DataRow(cells: [
            DataCell(Text(c.day)),
            DataCell(Text('${c.size}')),
            for (final r in c.retained)
              DataCell(pctCell(r == null ? null : (c.size == 0 ? 0.0 : r / c.size))),
          ]),
        DataRow(cells: [
          const DataCell(Text('Weighted avg', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('$totalSize')),
          for (final a in data.average) DataCell(pctCell(a)),
        ]),
      ],
    );
  }
}
