import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const sec = 1000000;
const f = Filters(from: d1, to: d1);

EventStore storeWith(List<RawEvent> events) {
  final s = EventStore.inMemory();
  addTearDown(s.close);
  s.replaceDay(d1, events);
  return s;
}

FunnelDef def(List<FunnelStepDef> steps, {FunnelOrder order = FunnelOrder.strict, int? window}) =>
    FunnelDef(name: 'x', windowMinutes: window, steps: steps, order: order);

List<int> players(EventStore s, FunnelDef d) => [for (final st in s.funnelEngine.run(d, f).steps) st.players];

void main() {
  group('operators', () {
    late EventStore s;
    setUp(() {
      s = storeWith([
        evx(d1, 1, 'level_start', 'u1', params: {'lvl': 3}),
        evx(d1, 1, 'level_start', 'u2', params: {'lvl': 5}),
        evx(d1, 1, 'level_start', 'u3', params: {'lvl': '7'}),
        evx(d1, 1, 'level_start', 'u4', params: {'lvl': 'x'}),
        evx(d1, 1, 'level_start', 'u5'),
        evx(d1, 1, 'level_start', 'u6', params: {'lvl': 10}),
      ]);
    });

    int count(ParamFilter p) => players(s, def([FunnelStepDef(event: 'level_start', params: [p])])).single;

    // lvl per player: u1 3, u2 5, u3 "7", u4 "x", u5 missing, u6 10.
    test('numeric compare parses text and skips non-numbers', () {
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.gte)), 3); // u2 u3 u6
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.gt)), 2); // u3 u6
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.lt)), 1); // u1
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.lte)), 2); // u1 u2
      expect(count(const ParamFilter('lvl', '4.5', op: FilterOp.gt)), 3); // decimals work: u2 u3 u6
    });

    test('text operators; a missing param never matches, even "is not"', () {
      expect(count(const ParamFilter('lvl', '5')), 1); // u2
      expect(count(const ParamFilter('lvl', '5', op: FilterOp.ne)), 4); // u1 u3 u4 u6, not u5
      expect(count(const ParamFilter('lvl', null, op: FilterOp.isIn, values: ['3', 'x'])), 2); // u1 u4
      expect(count(const ParamFilter('lvl', '1', op: FilterOp.contains)), 1); // u6 "10"
    });
  });

  test('or alternatives: any of the events matches the step', () {
    final s = storeWith([
      evx(d1, 1, 'a', 'u1'), evx(d1, 2, 'b', 'u1'),
      evx(d1, 1, 'a', 'u2'), evx(d1, 2, 'c', 'u2', params: {'k': 1}),
      evx(d1, 1, 'a', 'u3'), evx(d1, 2, 'c', 'u3', params: {'k': 2}), // c with k=2 does not match
    ]);
    final r = s.funnelEngine.run(
        def(const [
          FunnelStepDef(event: 'a'),
          FunnelStepDef(event: 'b', alternatives: [StepMatcher(event: 'c', params: [ParamFilter('k', '1')])]),
        ]),
        f);
    expect([for (final st in r.steps) st.players], [3, 2]);
    expect(r.steps[1].alternatives, const [StepMatcher(event: 'c', params: [ParamFilter('k', '1')])]);
  });

  group('exclusions (strict order)', () {
    test('exclusion between step 1 and 2 drops the player; after step 2 it does not', () {
      final s = storeWith([
        evx(d1, 1, 'first_open', 'u1'), evx(d1, 2, 'ad_shown', 'u1'), evx(d1, 3, 'purchase', 'u1'),
        evx(d1, 1, 'first_open', 'u2'), evx(d1, 2, 'purchase', 'u2'), evx(d1, 3, 'ad_shown', 'u2'),
        evx(d1, 1, 'first_open', 'u3'),
      ]);
      final r = s.funnelEngine.run(
          def(const [
            FunnelStepDef(event: 'first_open'),
            FunnelStepDef(event: 'purchase', exclude: [StepMatcher(event: 'ad_shown')]),
          ]),
          f);
      // u1 saw the ad first -> stops at step 1; u2 bought first -> step 2; u3 never bought.
      expect([for (final st in r.steps) st.players], [3, 1]);
      expect(r.steps[1].dropped, 2);
      expect(r.steps[1].exclude, const [StepMatcher(event: 'ad_shown')]);
    });

    test('exclusion only guards its own step', () {
      final s = storeWith([
        evx(d1, 1, 'first_open', 'u1'), evx(d1, 2, 'ad_shown', 'u1'),
        evx(d1, 3, 'tut', 'u1'), evx(d1, 4, 'purchase', 'u1'),
      ]);
      // ad_shown is between steps 1 and 2, but the exclusion belongs to step 3.
      expect(
          players(s, def(const [
            FunnelStepDef(event: 'first_open'),
            FunnelStepDef(event: 'tut'),
            FunnelStepDef(event: 'purchase', exclude: [StepMatcher(event: 'ad_shown')]),
          ])),
          [1, 1, 1]);
    });

    test('a row matching both the step and its exclusion counts as the step', () {
      final s = storeWith([evx(d1, 1, 'a', 'u1'), evx(d1, 2, 'b', 'u1')]);
      expect(
          players(s, def(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b', exclude: [StepMatcher(event: 'b')])])),
          [1, 1]);
    });
  });

  group('any order', () {
    late EventStore s;
    setUp(() {
      s = storeWith([
        // u1: c before b -> any order reaches 3, strict reaches 2.
        evx(d1, 0, 'a', 'u1'), evx(d1, 10 * sec, 'c', 'u1'), evx(d1, 20 * sec, 'b', 'u1'),
        // u2: never does b -> any order stays at step 1 (prefix rule), although c happened.
        evx(d1, 0, 'a', 'u2'), evx(d1, 10 * sec, 'c', 'u2'),
        // u3: b before entry does not count.
        evx(d1, 0, 'b', 'u3'), evx(d1, 10 * sec, 'a', 'u3'), evx(d1, 20 * sec, 'c', 'u3'),
      ]);
    });
    const steps = [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b'), FunnelStepDef(event: 'c')];

    test('counts, prefix rule and medians from step 1', () {
      final r = s.funnelEngine.run(def(steps, order: FunnelOrder.any), f);
      expect([for (final st in r.steps) st.players], [3, 1, 1]);
      // u1 only: b 20 s after entry, c 10 s after entry.
      expect(r.steps[1].medianSeconds, 20.0);
      expect(r.steps[2].medianSeconds, 10.0);
      expect(r.totalConversion, closeTo(1 / 3, 1e-9));
    });

    test('same data in strict order', () {
      expect(players(s, def(steps)), [3, 1, 0]);
    });

    test('one row cannot satisfy two steps', () {
      final t = storeWith([
        evx(d1, 0, 'a', 'u1'), evx(d1, 1, 'b', 'u1'),
        evx(d1, 0, 'a', 'u2'), evx(d1, 1, 'b', 'u2'), evx(d1, 2, 'b', 'u2'),
      ]);
      expect(
          players(t, def(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b'), FunnelStepDef(event: 'b')],
              order: FunnelOrder.any)),
          [2, 2, 1]);
    });

    test('window counted from entry', () {
      final t = storeWith([evx(d1, 0, 'a', 'u1'), evx(d1, 3600 * sec + 1, 'b', 'u1')]);
      expect(players(t, def(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b')], order: FunnelOrder.any, window: 60)),
          [1, 0]);
    });
  });

  test('paths lists each entered player with step times', () {
    final s = storeWith([
      evx(d1, 5, 'a', 'u1'), evx(d1, 9, 'b', 'u1'),
      evx(d1, 7, 'a', 'u2'),
      evx(d1, 1, 'b', 'u3'), // never entered
    ]);
    final paths = s.funnelEngine.paths(def(const [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b')]), f);
    expect([for (final p in paths) '${p.uid} ${p.reached} ${p.stepTs}'], ['u1 2 [5, 9]', 'u2 1 [7]']);
  });
}
