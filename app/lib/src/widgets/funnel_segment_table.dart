import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelSegmentTable extends StatelessWidget {
  const FunnelSegmentTable({super.key, required this.result});
  final FunnelResult result;

  @override
  Widget build(BuildContext context) {
    final tokens = AnalyticsTokens.of(context);
    final segments = result.segments;
    final steps = result.steps;

    if (segments.isEmpty) return const SizedBox.shrink();

    return DataTable(
      columnSpacing: 24,
      columns: [
        const DataColumn(label: Text('Segment')),
        const DataColumn(label: Text('Entered'), numeric: true),
        for (final s in steps)
          DataColumn(
            label: Text('Step ${s.index + 1}'),
            numeric: true,
          ),
        const DataColumn(label: Text('Total conv.'), numeric: true),
      ],
      rows: [
        for (var i = 0; i < segments.length; i++) ...[
          () {
            final seg = segments[i];
            final color = tokens.chart[i % tokens.chart.length];
            final entered = seg.steps.isEmpty ? 0 : seg.steps.first.players;
            return DataRow(cells: [
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(seg.value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
              DataCell(Text('$entered')),
              for (final st in seg.steps) DataCell(Text(fmtPct(st.fromFirst))),
              DataCell(Text(fmtPct(seg.totalConversion), style: const TextStyle(fontWeight: FontWeight.w600))),
            ]);
          }(),
        ],
      ],
    );
  }
}
