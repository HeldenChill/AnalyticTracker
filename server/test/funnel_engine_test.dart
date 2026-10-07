import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const base = 1000000000000; // arbitrary micros origin
const sec = 1000000;
const day = 86400 * sec;

FunnelDef onboarding({int? window = 1440}) => FunnelDef(name: 'Onboarding', windowMinutes: window, steps: const [
      FunnelStepDef(event: 'first_open'),
      FunnelStepDef(event: 'tut', params: [ParamFilter('step', '1')]),
      FunnelStepDef(event: 'tut', params: [ParamFilter('step', '3')]),
    ]);

EventStore seeded() {
  RawEvent e(int t, String name, String user, [Map<String, Object?> p = const {}]) =>
      evx(d1, base + t, name, user, params: p);
  final s = EventStore.inMemory();
  s.replaceDay(d1, [
    // u1: completes all three steps (gaps 10 s, 60 s)
    e(0, 'first_open', 'u1'), e(10 * sec, 'tut', 'u1', {'step': 1}), e(70 * sec, 'tut', 'u1', {'step': 3}),
    // u2: step 3 before step 1 -> strict order stops at step 2 (gap 20 s)
    e(0, 'first_open', 'u2'), e(5 * sec, 'tut', 'u2', {'step': 3}), e(20 * sec, 'tut', 'u2', {'step': 1}),
    // u3: tut before first_open -> only step 1
    e(1 * sec, 'tut', 'u3', {'step': 1}), e(2 * sec, 'first_open', 'u3'),
    // u4: string "1" matches; step 3 exactly at the window edge counts (gaps 30 s, 86370 s)
    e(0, 'first_open', 'u4'), e(30 * sec, 'tut', 'u4', {'step': '1'}), e(day, 'tut', 'u4', {'step': 3}),
    // u5: step 2 one microsecond past the window -> only step 1
    e(0, 'first_open', 'u5'), e(day + 1, 'tut', 'u5', {'step': 1}),
    // empty player id never counts
    e(0, 'first_open', ''),
  ]);
  return s;
}

void main() {
  late EventStore store;
  setUp(() => store = seeded());
  tearDown(() => store.close());

  const f = Filters(from: d1, to: d1);

  test('fixture: strict order, string param match, players per step', () {
    final r = store.funnelEngine.run(onboarding(), f);
    expect(r.steps.map((s) => s.players).toList(), [5, 3, 2]);
    expect(r.steps[0].toJson(), {
      'index': 0, 'event': 'first_open', 'params': <Object>[], 'players': 5,
      'fromPrevious': null, 'fromFirst': 1.0, 'dropped': null, 'medianSeconds': null,
    });
    expect(r.steps[1].fromPrevious, closeTo(0.6, 1e-9));
    expect(r.steps[1].fromFirst, closeTo(0.6, 1e-9));
    expect(r.steps[1].dropped, 2);
    expect(r.steps[1].medianSeconds, 20.0);
    expect(r.steps[2].fromPrevious, closeTo(2 / 3, 1e-9));
    expect(r.steps[2].fromFirst, closeTo(0.4, 1e-9));
    expect(r.steps[2].dropped, 1);
    expect(r.steps[2].medianSeconds, 43215.0);
    expect(r.totalConversion, closeTo(0.4, 1e-9));
    expect(r.biggestDropIndex, 1);
    expect(r.steps[2].params, const [ParamFilter('step', '3')]);
  });

  test('all param filters of a step must match (BUG-0008)', () {
    final s = EventStore.inMemory();
    addTearDown(s.close);
    s.replaceDay(d1, [
      // u1: Tut_1 start then Tut_1 end -> reaches step 2
      evx(d1, 1, 'tut', 'u1', params: {'id': 'Tut_1', 'step': 'start'}),
      evx(d1, 2, 'tut', 'u1', params: {'id': 'Tut_1', 'step': 'end'}),
      // u2: Tut_1 start then Tut_2 end -> id mismatch, stops at step 1
      evx(d1, 1, 'tut', 'u2', params: {'id': 'Tut_1', 'step': 'start'}),
      evx(d1, 2, 'tut', 'u2', params: {'id': 'Tut_2', 'step': 'end'}),
    ]);
    final r = s.funnelEngine.run(const FunnelDef(name: 'tut', windowMinutes: null, steps: [
      FunnelStepDef(event: 'tut', params: [ParamFilter('id', 'Tut_1'), ParamFilter('step', 'start')]),
      FunnelStepDef(event: 'tut', params: [ParamFilter('id', 'Tut_1'), ParamFilter('step', 'end')]),
    ]), f);
    expect(r.steps.map((x) => x.players).toList(), [2, 1]);
  });

  test('test-device events excluded unless includeTest (BUG-0007)', () {
    final s = EventStore.inMemory();
    addTearDown(s.close);
    s.replaceDay(d1, [
      evx(d1, 1, 'first_open', 'real'),
      evx(d1, 1, 'first_open', 'dev', params: {'debug_event': 1}),
    ]);
    const def = FunnelDef(name: 'x', windowMinutes: null, steps: [FunnelStepDef(event: 'first_open')]);
    expect(s.funnelEngine.run(def, f).steps.single.players, 1);
    expect(s.funnelEngine.run(def, f.withIncludeTest(true)).steps.single.players, 2);
  });

  test('window boundary', () {
    final oneHour = store.funnelEngine.run(onboarding(window: 60), f);
    expect(oneHour.steps.map((s) => s.players).toList(), [5, 3, 1]);
  });

  test('whole range window', () {
    final r = store.funnelEngine.run(onboarding(window: null), f);
    expect(r.steps.map((s) => s.players).toList(), [5, 4, 2]);
  });

  test('filters with no matching players give nulls', () {
    final r = store.funnelEngine.run(onboarding(), f.withPlatform('IOS'));
    expect(r.steps.map((s) => s.players).toList(), [0, 0, 0]);
    expect(r.steps[0].fromFirst, isNull);
    expect(r.steps[1].fromPrevious, isNull);
    expect(r.steps[1].dropped, 0);
    expect(r.totalConversion, isNull);
    expect(r.biggestDropIndex, isNull);
  });

  test('single-step funnel', () {
    final r = store.funnelEngine.run(
        const FunnelDef(name: 'x', windowMinutes: null, steps: [FunnelStepDef(event: 'first_open')]), f);
    expect(r.steps.single.players, 5);
    expect(r.totalConversion, 1.0);
    expect(r.biggestDropIndex, isNull);
  });

  test('biggest drop tie picks the earliest step', () {
    final s = EventStore.inMemory();
    addTearDown(s.close);
    // players 4 -> 2 -> 1: both later steps keep exactly 50%.
    s.replaceDay(d1, [
      evx(d1, 1, 'a', 'u1'), evx(d1, 2, 'b', 'u1'), evx(d1, 3, 'c', 'u1'),
      evx(d1, 1, 'a', 'u2'), evx(d1, 2, 'b', 'u2'),
      evx(d1, 1, 'a', 'u3'),
      evx(d1, 1, 'a', 'u4'),
    ]);
    final r = s.funnelEngine.run(const FunnelDef(name: 'x', windowMinutes: null, steps: [
      FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b'), FunnelStepDef(event: 'c'),
    ]), f);
    expect(r.steps.map((x) => x.players).toList(), [4, 2, 1]);
    expect(r.steps[1].fromPrevious, 0.5);
    expect(r.steps[2].fromPrevious, 0.5);
    expect(r.biggestDropIndex, 1);
  });

  test('repeated event steps need a later occurrence', () {
    final r = store.funnelEngine.run(const FunnelDef(name: 'x', windowMinutes: null, steps: [
      FunnelStepDef(event: 'first_open'), FunnelStepDef(event: 'first_open'),
    ]), f);
    expect(r.steps.map((x) => x.players).toList(), [5, 0]);
  });

  test('invalid definition throws ArgumentError', () {
    expect(() => store.funnelEngine.run(const FunnelDef(name: 'x', windowMinutes: 60, steps: []), f),
        throwsArgumentError);
  });
}
