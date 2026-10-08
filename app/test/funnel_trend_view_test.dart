import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/funnel_trend_view.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: buildTheme(AppStyle.midnight),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  final testResult = FunnelResult(
    steps: const [
      FunnelStepResult(
        index: 0,
        event: 'start',
        players: 100,
        fromPrevious: null,
        fromFirst: 1.0,
        dropped: null,
        medianSeconds: null,
      ),
      FunnelStepResult(
        index: 1,
        event: 'finish',
        players: 50,
        fromPrevious: 0.5,
        fromFirst: 0.5,
        dropped: 50,
        medianSeconds: null,
      ),
    ],
    totalConversion: 0.5,
    biggestDropIndex: 1,
    trend: const [
      FunnelTrendPoint(
        start: '2026-10-01',
        players: [50, 25],
        totalConversion: 0.5,
        incomplete: false,
      ),
      FunnelTrendPoint(
        start: '2026-10-02',
        players: [50, 20],
        totalConversion: 0.4,
        incomplete: true,
      ),
    ],
  );

  testWidgets('FunnelTrendView renders interval toggle, step picker and charts', (tester) async {
    FunnelInterval? chosenInterval;

    await tester.pumpWidget(wrap(
      FunnelTrendView(
        result: testResult,
        interval: FunnelInterval.day,
        onIntervalChanged: (i) => chosenInterval = i,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Interval toggle
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);

    // Verify Step picker default
    expect(find.text('Total conversion (all steps)'), findsOneWidget);

    // Verify Entered players section
    expect(find.text('Entered players per bucket'), findsOneWidget);

    // Tap Week interval button
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(chosenInterval, FunnelInterval.week);
  });
}
