import 'package:analytic_app/src/widgets/funnel_chart.dart';
import 'package:analytic_app/src/widgets/funnel_segment_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FunnelSegmentTable renders segment rows with percentages', (tester) async {
    const result = FunnelResult(
      steps: [
        FunnelStepResult(index: 0, event: 'e1', players: 10, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
        FunnelStepResult(index: 1, event: 'e2', players: 5, fromPrevious: 0.5, fromFirst: 0.5, dropped: 5, medianSeconds: null),
      ],
      totalConversion: 0.5,
      biggestDropIndex: 0,
      segments: [
        FunnelSegmentResult(
          value: 'ANDROID',
          steps: [
            FunnelSegmentStepResult(players: 10, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
            FunnelSegmentStepResult(players: 5, fromPrevious: 0.5, fromFirst: 0.5, dropped: 5, medianSeconds: null),
          ],
          totalConversion: 0.5,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FunnelSegmentTable(result: result),
        ),
      ),
    );

    expect(find.text('ANDROID'), findsOneWidget);
    expect(find.text('50%'), findsNWidgets(2)); // step 2 and total conversion
    expect(find.text('Segment'), findsOneWidget);
  });

  testWidgets('FunnelChart shows segment legend when segments present', (tester) async {
    const result = FunnelResult(
      steps: [
        FunnelStepResult(index: 0, event: 'e1', players: 10, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
      ],
      totalConversion: 1.0,
      biggestDropIndex: null,
      segments: [
        FunnelSegmentResult(
          value: 'v1.0',
          steps: [
            FunnelSegmentStepResult(players: 10, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
          ],
          totalConversion: 1.0,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FunnelChart(result: result),
        ),
      ),
    );

    expect(find.text('v1.0'), findsOneWidget);
  });
}
