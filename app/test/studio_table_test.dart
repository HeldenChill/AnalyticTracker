import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/stage_table.dart';
import 'package:analytic_app/src/widgets/studio_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_test_host.dart';
import 'support/studio_text_assertions.dart';

void main() {
  for (final style in AppStyle.values) {
    testWidgets('table wraps long identifiers in ${style.name}', (t) async {
      await pumpStudio(
          t,
          StudioTable(
            columns: const [
              StudioColumn('An unusually long descriptive event title',
                  width: 220),
              StudioColumn('Occurrences', numeric: true, width: 180),
            ],
            rows: [
              StudioRow([
                StudioTextCell(longIdentifier),
                const StudioTextCell('123456789012', numeric: true),
              ])
            ],
          ),
          style: style);
      expect(find.text(longIdentifier), findsOneWidget);
      expect(find.text('123456789012'), findsOneWidget);
      final text = t.renderObject<RenderBox>(find.text(longIdentifier));
      expect(text.size.width, lessThanOrEqualTo(220));
      expect(text.size.height, greaterThan(48));
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('numeric minimum width preserves all digits in ${style.name}', (t) async {
      for (final scale in [1.0, 1.5]) {
        await pumpStudio(t, const StudioTable(
          key: ValueKey('numeric-table'),
          columns: [StudioColumn('Players', width: 80, numeric: true)],
          rows: [StudioRow([
            StudioTextCell('123456789012', numeric: true,
                style: TextStyle(fontWeight: FontWeight.w700)),
          ])],
        ), style: style, textScale: scale);
        expectCompleteSingleLine(t, find.text('123456789012'));
        expect(t.takeException(), isNull);
      }
    });

    testWidgets('StageTable long measured count fits in ${style.name}', (t) async {
      await pumpStudio(t, const StageTable(stages: [
        StageRow(stage: 1, players: 123456789012, starts: 2,
          completes: 1, fails: 1, winRate: 0.5,
          attemptsPerClear: 2, dropOff: 0.1),
      ]), style: style, textScale: 1.5);
      expectCompleteSingleLine(t, find.text('123456789012'));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('numeric width reacts to inherited theme and scale changes', (t) async {
    t.view.physicalSize = const Size(720, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final scale in [1.0, 1.5]) {
      await t.pumpWidget(MaterialApp(
        theme: buildTheme(scale == 1 ? AppStyle.tremor : AppStyle.midnight),
        home: MediaQuery(data: MediaQueryData(
          size: const Size(720, 1200), textScaler: TextScaler.linear(scale)),
          child: const Scaffold(body: StudioTable(
            key: ValueKey('retained-numeric-table'),
            columns: [StudioColumn('Players', width: 80, numeric: true)],
            rows: [StudioRow([
              StudioTextCell('123456789012', width: 40, numeric: true),
            ])],
          )),
        ),
      ));
      await t.pumpAndSettle();
      expectCompleteSingleLine(t, find.text('123456789012'));
      expect(t.takeException(), isNull);
    }
  });
}
