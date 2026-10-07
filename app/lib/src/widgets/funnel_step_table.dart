import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelStepTable extends StatelessWidget {
  const FunnelStepTable({super.key, required this.result, this.order = FunnelOrder.strict});
  final FunnelResult result;
  final FunnelOrder order;

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
      dataRowMaxHeight: double.infinity,
      columns: [
        const DataColumn(label: Text('Step'), numeric: true),
        const DataColumn(label: Text('Event')),
        const DataColumn(label: Text('Players'), numeric: true),
        const DataColumn(label: Text('From previous'), numeric: true),
        const DataColumn(label: Text('From first'), numeric: true),
        const DataColumn(label: Text('Dropped'), numeric: true),
        DataColumn(
          label: Text(order == FunnelOrder.any ? 'Median time from step 1' : 'Median time'),
          numeric: true,
        ),
      ],
      rows: [
        for (final s in result.steps)
          DataRow(cells: [
            DataCell(Text('${s.index + 1}')),
            DataCell(ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.text)),
            )),
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
