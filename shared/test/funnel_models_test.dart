import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

Map<String, dynamic> roundTrip(Map<String, dynamic> j) => jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

const def = FunnelDef(name: 'Onboarding', windowMinutes: 1440, steps: [
  FunnelStepDef(event: 'first_open'),
  FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '1'),
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
        {'event': 'first_open', 'paramKey': null, 'paramValue': null},
        {'event': 'tut', 'paramKey': 'step', 'paramValue': '1'},
      ],
    });
  });

  test('empty strings in JSON become null filters', () {
    final s = FunnelStepDef.fromJson({'event': ' tut ', 'paramKey': '', 'paramValue': ''});
    expect(s, const FunnelStepDef(event: 'tut'));
    expect(s.filterLabel, isNull);
    expect(const FunnelStepDef(event: 'tut', paramKey: 'step', paramValue: '3').filterLabel, 'step = 3');
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
      expect(d(steps: const [FunnelStepDef(event: 'a', paramKey: 'step')]).validate(),
          'Step 1: set both parameter and value, or neither');
      expect(d(steps: const [FunnelStepDef(event: 'a', paramValue: '1')]).validate(),
          'Step 1: set both parameter and value, or neither');
      expect(d(steps: const [FunnelStepDef(event: 'a', paramKey: 'a.b', paramValue: '1')]).validate(),
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
      FunnelStepResult(index: 0, event: 'a', paramKey: null, paramValue: null, players: 5, fromPrevious: null, fromFirst: 1.0, dropped: null, medianSeconds: null),
      FunnelStepResult(index: 1, event: 'b', paramKey: 'k', paramValue: 'v', players: 3, fromPrevious: 0.6, fromFirst: 0.6, dropped: 2, medianSeconds: 20.0),
    ], totalConversion: 0.6, biggestDropIndex: 1);
    expect(FunnelResult.fromJson(roundTrip(r.toJson())).toJson(), r.toJson());
    final fromInts = FunnelStepResult.fromJson({
      'index': 1, 'event': 'b', 'paramKey': null, 'paramValue': null, 'players': 1,
      'fromPrevious': 1, 'fromFirst': 1, 'dropped': 0, 'medianSeconds': 20,
    });
    expect(fromInts.fromFirst, 1.0);
    expect(fromInts.medianSeconds, 20.0);
  });
}
