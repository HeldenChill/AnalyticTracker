import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/funnel_editor.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _values = {
  'lvl': [ParamBucket(value: '40', count: 2), ParamBucket(value: '1', count: 9), ParamBucket(value: '5', count: 4)],
  'id': [ParamBucket(value: 'Tut_1', count: 412), ParamBucket(value: 'Tut_2', count: 300)],
};

void main() {
  late FunnelEditorOutcome? outcome;

  Future<void> open(WidgetTester t, FunnelDef initial) async {
    t.view.physicalSize = const Size(1600, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    outcome = null;
    await t.pumpWidget(ProviderScope(
      overrides: [
        eventNamesProvider.overrideWith((ref) async => const ['first_open', 'level_start', 'tut']),
        paramKeysProvider.overrideWith((ref, q) async => const ['id', 'lvl']),
        paramValuesProvider.overrideWith((ref, q) async => _values[q.key] ?? const <ParamBucket>[]),
      ],
      child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
            onPressed: () async {
              outcome = await showFunnelEditor(context, initial: initial, onSave: (_) async => null);
            },
            child: const Text('open'),
          )))),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  ButtonStyleButton button(WidgetTester t, String text) => t.widget<ButtonStyleButton>(
      find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));

  Future<void> pickOperator(WidgetTester t, String from, String to) async {
    await t.tap(find.text(from).last);
    await t.pumpAndSettle();
    await t.tap(find.text(to).last);
    await t.pumpAndSettle();
  }

  testWidgets('number words offered for a parameter whose values are all numbers', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'level_start', params: [ParamFilter('lvl', '5')]),
    ]));
    await t.tap(find.text('is').last);
    await t.pumpAndSettle();
    expect(find.text('at least'), findsWidgets);
    expect(find.text('is one of'), findsWidgets);
  });

  testWidgets('number words hidden for a text parameter', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'tut', params: [ParamFilter('id', 'Tut_1')]),
    ]));
    await t.tap(find.text('is').last);
    await t.pumpAndSettle();
    expect(find.text('at least'), findsNothing);
    expect(find.text('is one of'), findsWidgets);
  });

  testWidgets('switching to "at least" shows a number box seeded with the median and the seen range', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'level_start', params: [ParamFilter('lvl', null)]),
    ]));
    await pickOperator(t, 'is', 'at least');
    // seen values 40, 1, 5 -> sorted 1, 5, 40 -> median 5, range 1 – 40
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    expect(find.text('seen 1 – 40'), findsOneWidget);
    await t.tap(find.byTooltip('Increase'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, '6'), findsOneWidget);
    await t.tap(find.text('Run'));
    await t.pumpAndSettle();
    expect(outcome!.def.steps.single.params.single, const ParamFilter('lvl', '6', op: FilterOp.gte));
  });

  testWidgets('"is one of" picks values from a checklist', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'tut', params: [ParamFilter('id', null)]),
    ]));
    await pickOperator(t, 'is', 'is one of');
    expect(button(t, 'Run').enabled, isFalse);
    expect(find.text('Step 1: pick at least one value for "id"'), findsOneWidget);
    await t.tap(find.text('Pick values'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tut_1 (412)'));
    await t.tap(find.text('Tut_2 (300)'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Tut_1, Tut_2'), findsOneWidget);
    expect(find.text('Summary: tut where id is one of Tut_1, Tut_2'), findsOneWidget);
    await t.tap(find.text('Run'));
    await t.pumpAndSettle();
    expect(outcome!.def.steps.single.params.single,
        const ParamFilter('id', null, op: FilterOp.isIn, values: ['Tut_1', 'Tut_2']));
  });

  testWidgets('or-event and exclusion buttons; Any order removes exclusions with a notice', (t) async {
    await open(t, const FunnelDef(name: 'F', windowMinutes: null, steps: [
      FunnelStepDef(event: 'first_open'),
      FunnelStepDef(event: 'tut', exclude: [StepMatcher(event: 'level_start')]),
    ]));
    expect(find.text('Add exclusion'), findsOneWidget, reason: 'step 2 only');
    expect(find.text('Drop the player if, before this step, they did:'), findsOneWidget);
    expect(find.text('Summary: first_open → tut (unless level_start first)'), findsOneWidget);
    await t.tap(find.text('Or another event').first);
    await t.pumpAndSettle();
    expect(find.text('— or —'), findsOneWidget);
    expect(button(t, 'Run').enabled, isFalse, reason: 'new or-event has no event yet');
    await t.tap(find.byTooltip('Remove or-event'));
    await t.pumpAndSettle();
    await t.tap(find.text('Any order'));
    await t.pumpAndSettle();
    expect(find.text('Exclusions removed: they need strict order'), findsOneWidget);
    expect(find.text('Add exclusion'), findsNothing);
    await t.tap(find.text('Run'));
    await t.pumpAndSettle();
    expect(outcome!.def.order, FunnelOrder.any);
    expect(outcome!.def.steps[1].exclude, isEmpty);
  });
}
