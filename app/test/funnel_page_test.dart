import 'package:analytic_app/src/pages/funnel_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const steps = [
  FunnelStepDef(event: 'first_open'),
  FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')]),
  FunnelStepDef(event: 'tut', params: [ParamFilter('step', '3')]),
];

const result = FunnelResult(steps: [
  FunnelStepResult(index: 0, event: 'first_open', players: 214, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
  FunnelStepResult(index: 1, event: 'tut', params: [ParamFilter('step', '1')], players: 198, fromPrevious: 198 / 214, fromFirst: 198 / 214, dropped: 16, medianSeconds: 40),
  FunnelStepResult(index: 2, event: 'tut', params: [ParamFilter('step', '3')], players: 160, fromPrevious: 160 / 198, fromFirst: 160 / 214, dropped: 38, medianSeconds: 130),
], totalConversion: 160 / 214, biggestDropIndex: 2);

Future<void> pump(WidgetTester t, List<Override> overrides) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: Scaffold(body: FunnelPage())),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('empty state', (t) async {
    await pump(t, [savedFunnelsProvider.overrideWith((ref) async => const <SavedFunnel>[])]);
    expect(find.text('No saved funnels yet'), findsOneWidget);
    expect(find.text('Create your first funnel'), findsOneWidget);
  });

  testWidgets('first saved funnel is selected and its result shown', (t) async {
    FunnelDef? requested;
    await pump(t, [
      savedFunnelsProvider.overrideWith((ref) async => const [
            SavedFunnel(id: 1, name: 'Onboarding', windowMinutes: 1440, steps: steps, updatedAt: 'x'),
            SavedFunnel(id: 2, name: 'Zeta', windowMinutes: 60, steps: [FunnelStepDef(event: 'a')], updatedAt: 'x'),
          ]),
      funnelResultProvider.overrideWith((ref, q) async {
        requested = q.def;
        return result;
      }),
    ]);
    expect(requested, const FunnelDef(name: 'Onboarding', windowMinutes: 1440, steps: steps));
    expect(find.text('Total conversion'), findsOneWidget);
    expect(find.text('Players entered'), findsOneWidget);
    expect(find.text('214'), findsWidgets);
    expect(find.text('Biggest drop: step 2 → 3'), findsOneWidget);
    expect(find.text('−19%'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('Strict order'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('no players at step 1 shows a note', (t) async {
    await pump(t, [
      savedFunnelsProvider.overrideWith((ref) async => const [
            SavedFunnel(id: 1, name: 'Onboarding', windowMinutes: 1440, steps: steps, updatedAt: 'x'),
          ]),
      funnelResultProvider.overrideWith((ref, q) async => const FunnelResult(steps: [
            FunnelStepResult(index: 0, event: 'first_open', players: 0, fromPrevious: null, fromFirst: null, dropped: null, medianSeconds: null),
          ], totalConversion: null, biggestDropIndex: null)),
    ]);
    expect(find.text('No players reached step 1 in this range'), findsOneWidget);
    expect(find.text('Biggest drop'), findsOneWidget);
  });
}
