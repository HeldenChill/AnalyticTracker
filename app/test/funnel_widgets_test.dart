import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/format.dart';
import 'package:analytic_app/src/widgets/funnel_chart.dart';
import 'package:analytic_app/src/widgets/funnel_editor.dart';
import 'package:analytic_app/src/widgets/funnel_step_table.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const result = FunnelResult(steps: [
  FunnelStepResult(index: 0, event: 'first_open', players: 214, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
  FunnelStepResult(index: 1, event: 'tut', params: [ParamFilter('step', '1')], players: 198, fromPrevious: 198 / 214, fromFirst: 198 / 214, dropped: 16, medianSeconds: 40),
  FunnelStepResult(index: 2, event: 'tut', params: [ParamFilter('step', '3')], players: 160, fromPrevious: 160 / 198, fromFirst: 160 / 214, dropped: 38, medianSeconds: 130),
], totalConversion: 160 / 214, biggestDropIndex: 2);

void setSize(WidgetTester t) {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  test('fmtDuration', () {
    expect(fmtDuration(null), '—');
    expect(fmtDuration(20), '20s');
    expect(fmtDuration(65), '1m 05s');
    expect(fmtDuration(43215), '12h 00m');
    expect(fmtDuration(90000), '1d 1h');
  });

  testWidgets('chart and table show conversion, filters and biggest drop', (t) async {
    setSize(t);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [
      FunnelChart(result: result),
      FunnelStepTable(result: result),
    ]))));
    expect(find.text('100%'), findsWidgets);
    expect(find.text('3. tut'), findsOneWidget);
    expect(find.text('step = 3'), findsWidgets); // chart label keeps the compact form
    expect(find.text('tut where step is 3'), findsOneWidget); // table uses plain words
    expect(find.text('−38'), findsOneWidget);
    expect(find.text('2m 10s'), findsOneWidget);
    expect(find.text('81%'), findsOneWidget); // step 3 from previous: 160/198
  });

  group('editor dialog', () {
    late FunnelEditorOutcome? outcome;
    late List<FunnelDef> saved;

    Future<void> open(WidgetTester t, {FunnelDef? initial, String? saveError}) async {
      setSize(t);
      outcome = null;
      saved = [];
      await t.pumpWidget(ProviderScope(
        overrides: [
          eventNamesProvider.overrideWith((ref) async => const ['first_open', 'tut']),
          paramKeysProvider.overrideWith((ref, q) async => const ['step']),
          paramValuesProvider.overrideWith(
              (ref, q) async => const [ParamBucket(value: '1', count: 9), ParamBucket(value: '3', count: 4)]),
        ],
        child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
              onPressed: () async {
                outcome = await showFunnelEditor(context, initial: initial, onSave: (d) async {
                  saved.add(d);
                  return saveError;
                });
              },
              child: const Text('open'),
            )))),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    ButtonStyleButton buttonWithText(WidgetTester t, String text) => t.widget<ButtonStyleButton>(
        find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));

    testWidgets('Add step disabled at 10 steps', (t) async {
      await open(t, initial: FunnelDef(name: 'F', windowMinutes: 60, steps: List.filled(10, const FunnelStepDef(event: 'tut'))));
      expect(find.text('Edit funnel'), findsOneWidget);
      expect(buttonWithText(t, 'Add step').enabled, isFalse);
    });

    testWidgets('empty name: hint shown, Save and Run disabled until a name is typed', (t) async {
      await open(t, initial: const FunnelDef(name: '', windowMinutes: 1440, steps: [FunnelStepDef(event: 'first_open')]));
      expect(find.text('Funnel name is required'), findsOneWidget);
      expect(buttonWithText(t, 'Save').enabled, isFalse);
      expect(buttonWithText(t, 'Run').enabled, isFalse);
      await t.enterText(find.widgetWithText(TextField, 'Funnel name'), 'Onboarding');
      await t.pumpAndSettle();
      expect(find.text('Funnel name is required'), findsNothing);
      expect(buttonWithText(t, 'Save').enabled, isTrue);
      expect(saved, isEmpty);
    });

    testWidgets('server error keeps dialog open', (t) async {
      await open(t, initial: const FunnelDef(name: 'F', windowMinutes: 1440, steps: [FunnelStepDef(event: 'first_open')]), saveError: 'Name taken');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(saved.length, 1);
      expect(find.text('Name taken'), findsOneWidget);
      expect(find.text('Edit funnel'), findsOneWidget);
      expect(outcome, isNull);
    });

    testWidgets('successful save closes with saved outcome', (t) async {
      const def = FunnelDef(name: 'F', windowMinutes: 1440, steps: [FunnelStepDef(event: 'first_open')]);
      await open(t, initial: def);
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Edit funnel'), findsNothing);
      expect(outcome!.saved, isTrue);
      expect(outcome!.def, def);
    });

    testWidgets('Run closes without saving', (t) async {
      await open(t, initial: const FunnelDef(name: 'F', windowMinutes: null, steps: [FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')])]));
      expect(find.text('Whole range'), findsOneWidget);
      await t.tap(find.text('Run'));
      await t.pumpAndSettle();
      expect(saved, isEmpty);
      expect(outcome!.saved, isFalse);
      expect(outcome!.def.steps.single.params, const [ParamFilter('step', '1')]);
    });

    testWidgets('second condition: Run disabled until the added row is filled or removed', (t) async {
      await open(t, initial: const FunnelDef(name: 'F', windowMinutes: null, steps: [FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')])]));
      expect(find.byTooltip('Remove filter'), findsOneWidget);
      await t.tap(find.text('And condition'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Remove filter'), findsNWidgets(2));
      expect(find.text('Step 1: set both parameter and value, or remove the filter'), findsOneWidget);
      expect(buttonWithText(t, 'Run').enabled, isFalse);
      await t.tap(find.byTooltip('Remove filter').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Run'));
      await t.pumpAndSettle();
      expect(outcome!.def.steps.single.params, const [ParamFilter('step', '1')]);
    });

    test('fmtCount drops .0 on whole numbers (BUG-0006)', () {
      expect(fmtCount(11.0), '11');
      expect(fmtCount(0), '0');
      expect(fmtCount(2.25), '2.3');
    });

    testWidgets('new funnel: add and remove steps', (t) async {
      await open(t);
      expect(find.text('New funnel'), findsOneWidget);
      expect(find.byTooltip('Remove step'), findsOneWidget);
      await t.tap(find.text('Add step'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Remove step'), findsNWidgets(2));
    });
  });
}
