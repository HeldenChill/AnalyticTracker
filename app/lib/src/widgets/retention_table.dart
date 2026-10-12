import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';
import 'studio_table.dart';

/// Cohort table. A null cell (day not observable yet) is blank, never 0%.
class RetentionTable extends StatelessWidget {
  const RetentionTable({super.key, required this.data});
  final RetentionData data;

  @override
  Widget build(BuildContext context) {
    final color = AnalyticsTokens.of(context).chart.first;

    Widget pctCell(double? rate) {
      if (rate == null) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08 + 0.6 * rate.clamp(0.0, 1.0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(fmtPct(rate)),
      );
    }

    final totalSize = data.cohorts.fold<int>(0, (a, c) => a + c.size);
    return StudioTable(
      columns: [
        const StudioColumn('Cohort (first_open)', width: 140),
        const StudioColumn('Players', width: 90, numeric: true),
        for (final o in data.offsets)
          StudioColumn('D$o', width: 70, numeric: true),
      ],
      rows: [
        for (final c in data.cohorts)
          StudioRow([
            StudioTextCell(c.day),
            StudioTextCell('${c.size}', numeric: true),
            for (final r in c.retained)
              pctCell(r == null ? null : (c.size == 0 ? 0.0 : r / c.size)),
          ]),
        StudioRow([
          const StudioTextCell('Weighted avg', style: TextStyle(fontWeight: FontWeight.bold)),
          StudioTextCell('$totalSize', numeric: true),
          for (final a in data.average) pctCell(a),
        ]),
      ],
    );
  }
}
