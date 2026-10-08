import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';

class FunnelStepTable extends StatelessWidget {
  const FunnelStepTable({
    super.key,
    required this.result,
    this.order = FunnelOrder.strict,
    this.onSelectStep,
  });
  final FunnelResult result;
  final FunnelOrder order;
  final void Function(int step, FunnelPlayerOutcome outcome)? onSelectStep;

  Future<void> _copyCsv(BuildContext context) async {
    final csv = toCsv([
      'Step',
      'Event',
      'Players',
      'From previous',
      'From first',
      'Dropped',
      order == FunnelOrder.any ? 'Median time from step 1' : 'Median time',
    ], [
      for (final s in result.steps)
        [
          s.index + 1,
          s.text,
          s.players,
          fmtPct(s.fromPrevious),
          fmtPct(s.fromFirst),
          s.dropped ?? '',
          fmtDuration(s.medianSeconds),
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

    Widget dropped(FunnelStepResult s) {
      if (s.dropped == null) return const Text('—');
      final text = '−${s.dropped}';
      final Widget badge;
      if (s.index != result.biggestDropIndex) {
        badge = Text(text);
      } else {
        badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.bad.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(text, style: TextStyle(color: tokens.bad, fontWeight: FontWeight.w600)),
        );
      }
      if (s.index >= 1 && onSelectStep != null) {
        return InkWell(
          onTap: () => onSelectStep!(s.index + 1, FunnelPlayerOutcome.dropped),
          child: badge,
        );
      }
      return badge;
    }

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
                DataCell(
                  s.index >= 1 && onSelectStep != null
                      ? InkWell(
                          onTap: () => onSelectStep!(s.index + 1, FunnelPlayerOutcome.converted),
                          child: Text('${s.players}'),
                        )
                      : Text('${s.players}'),
                ),
                DataCell(Text(fmtPct(s.fromPrevious))),
                DataCell(Text(fmtPct(s.fromFirst))),
                DataCell(dropped(s)),
                DataCell(Text(fmtDuration(s.medianSeconds))),
              ]),
          ],
        ),
      ],
    );
  }
}
