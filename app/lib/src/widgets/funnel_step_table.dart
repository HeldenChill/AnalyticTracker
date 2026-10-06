import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelStepTable extends StatelessWidget {
  const FunnelStepTable({super.key, required this.result});
  final FunnelResult result;

  @override
  Widget build(BuildContext context) {
    final tokens = AnalyticsTokens.of(context);

    Widget dropped(FunnelStepResult s) {
      if (s.dropped == null) return const Text('—');
      final text = '−${s.dropped}';
      if (s.index != result.biggestDropIndex) return Text(text);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.bad.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(color: tokens.bad, fontWeight: FontWeight.w600)),
      );
    }

    return DataTable(
      columnSpacing: 20,
      columns: const [
        DataColumn(label: Text('Step'), numeric: true),
        DataColumn(label: Text('Event')),
        DataColumn(label: Text('Filter')),
        DataColumn(label: Text('Players'), numeric: true),
        DataColumn(label: Text('From previous'), numeric: true),
        DataColumn(label: Text('From first'), numeric: true),
        DataColumn(label: Text('Dropped'), numeric: true),
        DataColumn(label: Text('Median time'), numeric: true),
      ],
      rows: [
        for (final s in result.steps)
          DataRow(cells: [
            DataCell(Text('${s.index + 1}')),
            DataCell(Text(s.event)),
            DataCell(Text(s.paramKey == null ? '—' : '${s.paramKey} = ${s.paramValue}')),
            DataCell(Text('${s.players}')),
            DataCell(Text(fmtPct(s.fromPrevious))),
            DataCell(Text(fmtPct(s.fromFirst))),
            DataCell(dropped(s)),
            DataCell(Text(fmtDuration(s.medianSeconds))),
          ]),
      ],
    );
  }
}
