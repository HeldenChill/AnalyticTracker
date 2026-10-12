import 'package:analytic_app/src/view_models/storage_observations.dart';
import 'package:analytic_app/src/widgets/coverage_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const calendarRows = [
  StoredObservation(
      day: '2026-10-30', count: 12, availability: DayAvailability.stored),
  StoredObservation(
      day: '2026-10-31', count: null, availability: DayAvailability.missing),
  StoredObservation(
      day: '2026-11-01', count: 0, availability: DayAvailability.stored),
];

void expectCompleteWrappedText(WidgetTester t, Finder finder) {
  expect(finder, findsOneWidget);
  final textWidget = t.widget<Text>(finder);
  expect(textWidget.data, isNotNull);
}

void main() {
  testWidgets('renders empty message for empty observations', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CoverageCalendar(observations: []),
      ),
    ));
    expect(find.text('No dates in this interval'), findsOneWidget);
  });

  testWidgets('partial month uses actual weekday and cells fit scaled labels',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data:
            MediaQueryData(textScaler: TextScaler.linear(1.5), boldText: true),
        child: Scaffold(
          body: SizedBox(
            width: 280,
            child: SingleChildScrollView(
              child: CoverageCalendar(observations: calendarRows),
            ),
          ),
        ),
      ),
    ));
    expect(t.takeException(), isNull);
    final first =
        t.getRect(find.byKey(const ValueKey('coverage-day:2026-10-30')));
    final friday =
        t.getRect(find.byKey(const ValueKey('coverage-weekday:2026-10:5')));
    expect(first.center.dx, closeTo(friday.center.dx, .5));
    for (final row in calendarRows) {
      final finder = find.byKey(ValueKey('coverage-number:${row.day}'));
      expectCompleteWrappedText(t, finder);
      final rect = t.getRect(finder);
      final cell = t.getRect(find.byKey(ValueKey('coverage-day:${row.day}')));
      expect(cell.contains(rect.topLeft) && cell.contains(rect.bottomRight),
          isTrue);
    }
    expect(find.byTooltip('2026-10-29: missing'), findsNothing);
    expect(find.byTooltip('2026-10-31: missing'), findsOneWidget);
    expect(find.byTooltip('2026-11-01: stored, 0 events'), findsOneWidget);
  });

  testWidgets('keyboard focus reveals full calendar date status and count',
      (t) async {
    final semantics = t.ensureSemantics();
    final before = FocusNode();
    addTearDown(before.dispose);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(
              focusNode: before,
              onPressed: () {},
              child: const Text('Before calendar'),
            ),
            const CoverageCalendar(observations: calendarRows),
          ],
        ),
      ),
    ));
    before.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('2026-10-30: stored, 12 events'), findsOneWidget);
    expect(
        find.bySemanticsLabel('2026-10-30: stored, 12 events'), findsWidgets);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('2026-10-31: missing'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(t.takeException(), isNull);
    semantics.dispose();
  });
}
