import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelSegmentTable extends StatelessWidget {
  const FunnelSegmentTable({super.key, required this.result});
  final FunnelResult result;

  Future<void> _copyCsv(BuildContext context) async {
    final csv = toCsv([
      'Segment',
      'Entered',
      for (final s in result.steps) 'Step ${s.index + 1}',
      'Total conversion',
    ], [
      for (final seg in result.segments)
        [
          seg.value,
          seg.steps.isEmpty ? 0 : seg.steps.first.players,
          for (final st in seg.steps) fmtPct(st.fromFirst),
          fmtPct(seg.totalConversion),
        ],
    ]);
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied CSV to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AnalyticsTokens.of(context);
    final segments = result.segments;
    final steps = result.steps;

    if (segments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => _copyCsv(context),
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Copy CSV'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DataTable(
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
        ),
      ],
    );
  }
}
