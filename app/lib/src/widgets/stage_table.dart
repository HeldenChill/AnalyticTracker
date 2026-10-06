import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';

import 'format.dart';

class StageTable extends StatelessWidget {
  const StageTable({super.key, required this.stages});
  final List<StageRow> stages;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columnSpacing: 18,
      columns: const [
        DataColumn(label: Text('Stage'), numeric: true),
        DataColumn(label: Text('Players'), numeric: true),
        DataColumn(label: Text('Starts'), numeric: true),
        DataColumn(label: Text('Completes'), numeric: true),
        DataColumn(label: Text('Fails'), numeric: true),
        DataColumn(label: Text('Win rate'), numeric: true),
        DataColumn(label: Text('Attempts/clear'), numeric: true),
        DataColumn(label: Text('Drop-off'), numeric: true),
      ],
      rows: [
        for (final s in stages)
          DataRow(cells: [
            DataCell(Text('${s.stage}')),
            DataCell(Text('${s.players}')),
            DataCell(Text('${s.starts}')),
            DataCell(Text('${s.completes}')),
            DataCell(Text('${s.fails}')),
            DataCell(Text(fmtPct(s.winRate))),
            DataCell(Text(fmtDecimal(s.attemptsPerClear))),
            DataCell(Text(fmtPct(s.dropOff))),
          ]),
      ],
    );
  }
}
