import 'package:analytic_app/src/state/funnel_draft.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const or1 = MatcherSlot.match(1);
  const ex0 = MatcherSlot.exclude(0);

  test('or-events: add up to 2, edit, remove; own event cannot be removed', () {
    final d = FunnelDraft(steps: [const FunnelStepDef(event: 'level_start')]);
    d.addAlternative(0);
    d.addAlternative(0);
    d.addAlternative(0);
    expect(d.steps[0].alternatives.length, 2);
    expect(d.canAddAlternative(0), isFalse);
    d.setEvent(0, 'level_skip', slot: or1);
    d.addParam(0, slot: or1);
    d.setParamKey(0, 0, 'lvl', slot: or1);
    d.setParamValue(0, 0, '3', slot: or1);
    expect(d.steps[0].alternatives[0], const StepMatcher(event: 'level_skip', params: [ParamFilter('lvl', '3')]));
    expect(d.steps[0].event, 'level_start', reason: 'editing an or-event leaves the own event alone');
    d.removeMatcher(0, const MatcherSlot.match(2));
    d.removeMatcher(0, MatcherSlot.own);
    expect(d.steps[0].matchers.map((m) => m.event).toList(), ['level_start', 'level_skip']);
  });

  test('exclusions: never on step 1, max 3, only in strict order', () {
    final d = FunnelDraft(steps: [const FunnelStepDef(event: 'a'), const FunnelStepDef(event: 'b')]);
    expect(d.canAddExclusion(0), isFalse);
    d.addExclusion(0);
    expect(d.steps[0].exclude, isEmpty);
    for (var i = 0; i < 5; i++) {
      d.addExclusion(1);
    }
    expect(d.steps[1].exclude.length, 3);
    d.setEvent(1, 'ad_shown', slot: ex0);
    d.removeMatcher(1, const MatcherSlot.exclude(2));
    expect(d.steps[1].exclude.map((m) => m.event).toList(), ['ad_shown', '']);
    d.setOrder(FunnelOrder.any);
    expect(d.steps[1].exclude, isEmpty);
    expect(d.canAddExclusion(1), isFalse);
    expect(d.toDef().order, FunnelOrder.any);
  });

  test('operator change keeps a fitting value, else uses the seed', () {
    final d = FunnelDraft(steps: [
      const FunnelStepDef(event: 'level_start', params: [ParamFilter('lvl', '5')]),
    ]);
    d.setParamOp(0, 0, FilterOp.gte, seed: '9');
    expect(d.steps[0].params.single, const ParamFilter('lvl', '5', op: FilterOp.gte), reason: '"5" is a number: kept');
    d.setParamOp(0, 0, FilterOp.isIn);
    expect(d.steps[0].params.single, const ParamFilter('lvl', null, op: FilterOp.isIn));
    d.setParamValues(0, 0, ['1', '2']);
    expect(d.steps[0].params.single.values, ['1', '2']);
    d.setParamOp(0, 0, FilterOp.lt, seed: '9');
    expect(d.steps[0].params.single, const ParamFilter('lvl', '9', op: FilterOp.lt), reason: 'in-list cannot carry over');
    d.setParamKey(0, 0, 'stg');
    expect(d.steps[0].params.single, const ParamFilter('stg', null), reason: 'new parameter resets to "is"');
  });

  test('text value does not carry into a number operator', () {
    final d = FunnelDraft(steps: [
      const FunnelStepDef(event: 'tut', params: [ParamFilter('step', 'end')]),
    ]);
    d.setParamOp(0, 0, FilterOp.gt);
    expect(d.steps[0].params.single, const ParamFilter('step', null, op: FilterOp.gt));
    d.setParamOp(0, 0, FilterOp.contains);
    expect(d.steps[0].params.single.value, isNull);
  });

  test('fromDef keeps order and richer steps', () {
    const def = FunnelDef(name: 'X', windowMinutes: 60, order: FunnelOrder.any, steps: [
      FunnelStepDef(event: 'a', alternatives: [StepMatcher(event: 'b')]),
    ]);
    expect(FunnelDraft.fromDef(def).toDef(), def);
  });
}
