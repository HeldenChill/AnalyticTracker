import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/screens/funnel_screen.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submitting steps shows users and percent of first step', (t) async {
    String? requested;
    await t.pumpWidget(ProviderScope(
      overrides: [
        funnelProvider.overrideWith((ref, q) async {
          requested = q.steps;
          return const [
            FunnelStep(eventName: 'stg_start', users: 200),
            FunnelStep(eventName: 'stg_cmp', users: 50),
          ];
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: FunnelScreen())),
    ));
    expect(find.textContaining('Enter steps'), findsOneWidget);

    await t.enterText(find.byType(TextField), ' stg_start , stg_cmp ,');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    expect(requested, 'stg_start,stg_cmp');
    expect(find.text('1. stg_start'), findsOneWidget);
    expect(find.text('200 · 100%'), findsOneWidget);
    expect(find.text('50 · 25%'), findsOneWidget);
  });
}
