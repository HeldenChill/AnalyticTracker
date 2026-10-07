import 'package:analytic_app/src/state/funnel_draft.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new draft has one empty step and the default window', () {
    final d = FunnelDraft();
    expect(d.steps, [const FunnelStepDef(event: '')]);
    expect(d.windowMinutes, 1440);
  });

  test('add stops at 10 steps', () {
    final d = FunnelDraft();
    for (var i = 0; i < 20; i++) {
      d.add();
    }
    expect(d.steps.length, 10);
    expect(d.canAdd, isFalse);
    d.duplicate(0);
    expect(d.steps.length, 10);
  });

  test('move keeps param filter attached to its step', () {
    final d = FunnelDraft(steps: [
      const FunnelStepDef(event: 'first_open'),
      const FunnelStepDef(event: 'tut', params: [ParamFilter('step', '3')]),
    ]);
    d.moveUp(1);
    expect(d.steps, [
      const FunnelStepDef(event: 'tut', params: [ParamFilter('step', '3')]),
      const FunnelStepDef(event: 'first_open'),
    ]);
    d.moveDown(0);
    expect(d.steps[1], const FunnelStepDef(event: 'tut', params: [ParamFilter('step', '3')]));
    d.moveUp(0);
    d.moveDown(1);
    expect(d.steps.length, 2);
  });

  test('setEvent clears filters; setParamKey clears value', () {
    final d = FunnelDraft(steps: [const FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')])]);
    d.setParamKey(0, 0, 'skipped');
    expect(d.steps[0], const FunnelStepDef(event: 'tut', params: [ParamFilter('skipped', null)]));
    d.setParamValue(0, 0, '0');
    expect(d.steps[0], const FunnelStepDef(event: 'tut', params: [ParamFilter('skipped', '0')]));
    d.setEvent(0, 'first_open');
    expect(d.steps[0], const FunnelStepDef(event: 'first_open'));
  });

  test('two filters per step: add, edit second, remove first, cap at 5 (BUG-0008)', () {
    final d = FunnelDraft(steps: [const FunnelStepDef(event: 'tut', params: [ParamFilter('id', 'Tut_1')])]);
    d.addParam(0);
    d.setParamKey(0, 1, 'step');
    d.setParamValue(0, 1, 'end');
    expect(d.steps[0].params, const [ParamFilter('id', 'Tut_1'), ParamFilter('step', 'end')]);
    expect(d.toDef().validate(), 'Funnel name is required', reason: 'filters themselves are valid');
    d.removeParam(0, 0);
    expect(d.steps[0].params, const [ParamFilter('step', 'end')]);
    for (var i = 0; i < 10; i++) {
      d.addParam(0);
    }
    expect(d.steps[0].params.length, 5);
    expect(d.canAddParam(0), isFalse);
  });

  test('duplicate inserts a copy after; remove keeps at least one step', () {
    final d = FunnelDraft(steps: [const FunnelStepDef(event: 'a', params: [ParamFilter('k', 'v')])]);
    d.duplicate(0);
    expect(d.steps, [
      const FunnelStepDef(event: 'a', params: [ParamFilter('k', 'v')]),
      const FunnelStepDef(event: 'a', params: [ParamFilter('k', 'v')]),
    ]);
    d.remove(0);
    d.remove(0);
    expect(d.steps.length, 1);
  });

  test('fromDef and toDef round trip; name trimmed', () {
    const def = FunnelDef(name: 'X', windowMinutes: null, steps: [FunnelStepDef(event: 'a')]);
    final d = FunnelDraft.fromDef(def)..name = '  X  ';
    expect(d.toDef(), def);
    d.steps.add(const FunnelStepDef(event: 'b'));
    expect(def.steps.length, 1, reason: 'draft must copy, not share, the step list');
  });
}
