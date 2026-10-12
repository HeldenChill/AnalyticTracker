import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import 'format.dart';
import 'studio_table.dart';

class StageTable extends StatelessWidget {
  const StageTable({super.key, required this.stages});
  final List<StageRow> stages;

  @override
  Widget build(BuildContext context) {
    return StudioTable(
      columns: const [
        StudioColumn('Stage', width: 70, numeric: true),
        StudioColumn('Players', width: 80, numeric: true),
        StudioColumn('Starts', width: 80, numeric: true),
        StudioColumn('Completes', width: 90, numeric: true),
        StudioColumn('Fails', width: 80, numeric: true),
        StudioColumn('Win rate', width: 90, numeric: true),
        StudioColumn('Attempts/clear', width: 120, numeric: true),
        StudioColumn('Drop-off', width: 90, numeric: true),
      ],
      rows: [
        for (final s in stages)
          StudioRow([
            StudioTextCell('${s.stage}', numeric: true),
            StudioTextCell('${s.players}', numeric: true),
            StudioTextCell('${s.starts}', numeric: true),
            StudioTextCell('${s.completes}', numeric: true),
            StudioTextCell('${s.fails}', numeric: true),
            StudioTextCell(fmtPct(s.winRate), numeric: true),
            StudioTextCell(fmtDecimal(s.attemptsPerClear), numeric: true),
            StudioTextCell(fmtPct(s.dropOff), numeric: true),
          ]),
      ],
    );
  }
}
