import 'package:analytic_app/src/widgets/funnel_step_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FunnelStepTable has Copy CSV button that copies RFC 4180 data', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const result = FunnelResult(
      steps: [
        FunnelStepResult(index: 0, event: 'step 1', players: 100, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
        FunnelStepResult(index: 1, event: 'step 2', players: 40, fromPrevious: 0.4, fromFirst: 0.4, dropped: 60, medianSeconds: 12.0),
      ],
      totalConversion: 0.4,
      biggestDropIndex: 1,
    );

    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        copiedText = (methodCall.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FunnelStepTable(result: result)),
    ));

    final copyBtn = find.widgetWithText(OutlinedButton, 'Copy CSV');
    expect(copyBtn, findsOneWidget);

    await tester.tap(copyBtn);
    await tester.pump();

    expect(copiedText, contains('Step,Event,Players,From previous,From first,Dropped,Median time'));
    expect(copiedText, contains('1,step 1,100,—,100%,,—'));
    expect(copiedText, contains('2,step 2,40,40%,40%,60,12s'));
  });
}
