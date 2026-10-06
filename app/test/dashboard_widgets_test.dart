import 'package:analytic_app/src/widgets/format.dart';
import 'package:analytic_app/src/widgets/kpi_card.dart';
import 'package:analytic_app/src/widgets/retention_table.dart';
import 'package:analytic_app/src/widgets/stage_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );

void main() {
  test('format helpers', () {
    expect(fmtPct(null), '—');
    expect(fmtPct(0.284), '28%');
    expect(fmtDecimal(null), '—');
    expect(fmtDecimal(1.25), '1.3');
    expect(pctChange(112, 100), closeTo(0.12, 1e-9));
    expect(pctChange(5, 0), isNull);
    expect(pctChange(5, null), isNull);
  });

  testWidgets('KpiCard shows value and delta direction', (t) async {
    await t.pumpWidget(host(const Column(children: [
      KpiCard(title: 'DAU (avg)', value: '37', delta: 0.12),
      KpiCard(title: 'Uninstalls', value: '9', delta: 0.5, higherIsBetter: false),
      KpiCard(title: 'Sessions', value: '3'),
    ])));
    expect(find.text('DAU (avg)'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);
    expect(find.text('▲ 12% vs prev'), findsOneWidget);
    expect(find.text('▲ 50% vs prev'), findsOneWidget);
    expect(find.textContaining('vs prev'), findsNWidgets(2));
    final up = t.widget<Text>(find.text('▲ 12% vs prev'));
    final badUp = t.widget<Text>(find.text('▲ 50% vs prev'));
    expect(up.style!.color, Colors.green);
    expect(badUp.style!.color, Colors.red);
  });

  testWidgets('RetentionTable blank vs 0%', (t) async {
    await t.pumpWidget(host(const RetentionTable(
      data: RetentionData(
        offsets: [1, 3, 7],
        lastDataDay: '2026-10-08',
        cohorts: [RetentionCohort(day: '2026-10-05', size: 2, retained: [1, 0, null])],
        average: [0.5, 0.0, null],
      ),
    )));
    expect(find.text('D7'), findsOneWidget);
    expect(find.text('Weighted avg'), findsOneWidget);
    expect(find.text('50%'), findsNWidgets(2));
    expect(find.text('0%'), findsNWidgets(2));
    expect(find.textContaining('%'), findsNWidgets(4));
  });

  testWidgets('StageTable formats rates and blanks', (t) async {
    await t.pumpWidget(host(const StageTable(stages: [
      StageRow(stage: 1, players: 2, starts: 3, completes: 1, fails: 2, winRate: 1 / 3, attemptsPerClear: 2.0, dropOff: 0.5),
      StageRow(stage: 2, players: 1, starts: 1, completes: 0, fails: 0, winRate: null, attemptsPerClear: null, dropOff: null),
    ])));
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('2.0'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
  });
}
