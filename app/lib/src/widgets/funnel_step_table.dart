import '../presentation/funnel_language.dart';
import 'vocabulary_scope.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/analytics_tokens.dart';
import 'format.dart';
import 'studio_table.dart';

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
      if (s.dropped == null) return const StudioTextCell('—', numeric: true);
      final text = '−${s.dropped}';
      final Widget badge;
      if (s.index != result.biggestDropIndex) {
        badge = StudioTextCell(text, numeric: true);
      } else {
        badge = Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.bad.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(text,
                style:
                    TextStyle(color: tokens.bad, fontWeight: FontWeight.w600)),
          ),
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
        StudioTable(
          columns: [
            const StudioColumn('Step', width: 60, numeric: true),
            const StudioColumn('Event', width: 320),
            const StudioColumn('Players', width: 90, numeric: true),
            const StudioColumn('From previous', width: 120, numeric: true),
            const StudioColumn('From first', width: 100, numeric: true),
            const StudioColumn('Dropped', width: 90, numeric: true),
            StudioColumn(
              order == FunnelOrder.any
                  ? 'Median time from step 1'
                  : 'Median time',
              width: 140,
              numeric: true,
            ),
          ],
          rows: [
            for (final s in result.steps)
              StudioRow([
                StudioTextCell('${s.index + 1}', numeric: true),
                StudioTextCell(resultLanguage(s, VocabularyScope.of(context))),
                s.index >= 1 && onSelectStep != null
                    ? InkWell(
                        onTap: () => onSelectStep!(
                            s.index + 1, FunnelPlayerOutcome.converted),
                        child: StudioTextCell('${s.players}', numeric: true),
                      )
                    : StudioTextCell('${s.players}', numeric: true),
                StudioTextCell(fmtPct(s.fromPrevious), numeric: true),
                StudioTextCell(fmtPct(s.fromFirst), numeric: true),
                dropped(s),
                StudioTextCell(fmtDuration(s.medianSeconds), numeric: true),
              ]),
          ],
        ),
      ],
    );
  }
}
