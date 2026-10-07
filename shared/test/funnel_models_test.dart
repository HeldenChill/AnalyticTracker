import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> j) => jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

const def = FunnelDef(name: 'Onboarding', windowMinutes: 1440, steps: [
  FunnelStepDef(event: 'first_open'),
  FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')]),
]);

void main() {
  test('FunnelDef round trip and equality', () {
    final back = FunnelDef.fromJson(roundTrip(def.toJson()));
    expect(back, def);
    expect(back.hashCode, def.hashCode);
    expect(def.toJson(), {
      'name': 'Onboarding',
      'windowMinutes': 1440,
      'steps': [
        {'event': 'first_open', 'params': <Object>[]},
        {
          'event': 'tut',
          'params': [
            {'key': 'step', 'value': '1'},
          ],
        },
      ],
    });
  });

  test('legacy single paramKey/paramValue JSON still reads (BUG-0008)', () {
    final s = FunnelStepDef.fromJson({'event': ' tut ', 'paramKey': '', 'paramValue': ''});
    expect(s, const FunnelStepDef(event: 'tut'));
    expect(s.filterLabel, isNull);
    expect(FunnelStepDef.fromJson({'event': 'tut', 'paramKey': 'step', 'paramValue': '1'}),
        const FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')]));
    expect(FunnelStepDef.fromJson({'event': 'tut', 'paramKey': null, 'paramValue': null}),
        const FunnelStepDef(event: 'tut'));
  });

  test('two filters per step round trip and label', () {
    const s = FunnelStepDef(event: 'tut', params: [ParamFilter('id', 'Tut_1'), ParamFilter('step', 'end')]);
    expect(FunnelStepDef.fromJson(roundTrip(s.toJson())), s);
    expect(s.filterLabel, 'id = Tut_1, step = end');
    expect(const FunnelStepDef(event: 'tut', params: [ParamFilter('step', '3')]).filterLabel, 'step = 3');
  });

  test('equality differs on window and steps', () {
    expect(def == FunnelDef(name: def.name, windowMinutes: null, steps: def.steps), isFalse);
    expect(def == FunnelDef(name: def.name, windowMinutes: 1440, steps: def.steps.sublist(0, 1)), isFalse);
  });

  group('validate', () {
    FunnelDef d({String name = 'F', int? window = 60, List<FunnelStepDef>? steps}) =>
        FunnelDef(name: name, windowMinutes: window, steps: steps ?? const [FunnelStepDef(event: 'a')]);

    test('valid', () {
      expect(def.validate(), isNull);
      expect(d(window: null).validate(), isNull);
    });
    test('messages in order', () {
      expect(d(name: '  ').validate(), 'Funnel name is required');
      expect(d(steps: const []).validate(), 'Add at least one step');
      expect(d(steps: List.filled(11, const FunnelStepDef(event: 'a'))).validate(), 'A funnel allows at most 10 steps');
      expect(d(steps: const [FunnelStepDef(event: 'a'), FunnelStepDef(event: ' ')]).validate(), 'Step 2: pick an event');
      expect(d(steps: const [FunnelStepDef(event: 'a', params: [ParamFilter('step', null)])]).validate(),
          'Step 1: set both parameter and value, or remove the filter');
      expect(d(steps: const [FunnelStepDef(event: 'a', params: [ParamFilter('', '1')])]).validate(),
          'Step 1: set both parameter and value, or remove the filter');
      expect(
          d(steps: const [
            FunnelStepDef(event: 'a', params: [ParamFilter('step', '1'), ParamFilter('step', '2')]),
          ]).validate(),
          'Step 1: parameter "step" is used twice');
      expect(
          d(steps: [
            FunnelStepDef(event: 'a', params: [for (var i = 0; i < 6; i++) ParamFilter('k$i', '1')]),
          ]).validate(),
          'Step 1: at most 5 parameter filters');
      expect(d(steps: const [FunnelStepDef(event: 'a', params: [ParamFilter('a.b', '1')])]).validate(),
          'Step 1: parameter name may only use letters, digits and _');
      expect(d(window: 0).validate(), 'Time window must be positive');
    });
    test('10 steps allowed', () {
      expect(d(steps: List.filled(10, const FunnelStepDef(event: 'a'))).validate(), isNull);
    });
  });

  test('window labels', () {
    expect([for (final w in funnelWindowOptions) funnelWindowLabel(w)], ['1 hour', '1 day', '7 days', 'Whole range']);
    expect(funnelWindowLabel(120), '2 hours');
    expect(funnelWindowLabel(2880), '2 days');
    expect(funnelWindowLabel(45), '45 min');
  });

  test('SavedFunnel round trip and def', () {
    const s = SavedFunnel(id: 3, name: 'Onboarding', windowMinutes: 1440, steps: [FunnelStepDef(event: 'a')], updatedAt: '2026-10-06T00:00:00.000Z');
    final back = SavedFunnel.fromJson(roundTrip(s.toJson()));
    expect(back.toJson(), s.toJson());
    expect(back.def, const FunnelDef(name: 'Onboarding', windowMinutes: 1440, steps: [FunnelStepDef(event: 'a')]));
  });

  test('FunnelResult round trip with nulls and int JSON numbers', () {
    const r = FunnelResult(steps: [
      FunnelStepResult(index: 0, event: 'a', players: 5, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
      FunnelStepResult(index: 1, event: 'b', params: [ParamFilter('k', 'v')], players: 3, fromPrevious: 0.6, fromFirst: 0.6, dropped: 2, medianSeconds: 20.0),
    ], totalConversion: 0.6, biggestDropIndex: 1);
    expect(FunnelResult.fromJson(roundTrip(r.toJson())).toJson(), r.toJson());
    final fromInts = FunnelStepResult.fromJson({
      'index': 1, 'event': 'b', 'players': 1,
      'fromPrevious': 1, 'fromFirst': 1, 'dropped': 0, 'medianSeconds': 20,
    });
    expect(fromInts.fromFirst, 1.0);
    expect(fromInts.medianSeconds, 20.0);
  });
}
