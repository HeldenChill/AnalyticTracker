import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

import 'helpers.dart';

FunnelDef def(String name, {int? window = 1440}) =>
    FunnelDef(name: name, windowMinutes: window, steps: const [FunnelStepDef(event: 'first_open')]);

void main() {
  late EventStore store;
  setUp(() => store = EventStore.inMemory());
  tearDown(() => store.close());

  test('create, get, list sorted by name', () {
    final b = store.funnels.create(def('beta'), now: DateTime.utc(2026, 10, 6));
    final a = store.funnels.create(def('Alpha'));
    expect(b.id, isNot(a.id));
    expect(b.updatedAt, '2026-10-06T00:00:00.000Z');
    expect(store.funnels.get(b.id)!.def, def('beta'));
    expect(store.funnels.list().map((f) => f.name), ['Alpha', 'beta']);
  });

  test('update replaces definition and timestamp; unknown id gives null', () {
    final f = store.funnels.create(def('A'), now: DateTime.utc(2026, 1, 1));
    final u = store.funnels.update(f.id, def('A2', window: null), now: DateTime.utc(2026, 2, 1))!;
    expect(u.id, f.id);
    expect(u.name, 'A2');
    expect(u.windowMinutes, isNull);
    expect(u.updatedAt, '2026-02-01T00:00:00.000Z');
    expect(store.funnels.update(999, def('X')), isNull);
  });

  test('delete', () {
    final f = store.funnels.create(def('A'));
    expect(store.funnels.delete(f.id), isTrue);
    expect(store.funnels.delete(f.id), isFalse);
    expect(store.funnels.list(), isEmpty);
  });

  test('invalid definition rejected', () {
    expect(() => store.funnels.create(def(' ')),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'Funnel name is required')));
  });

  test('paramKeys lists distinct keys for an event in range', () {
    store.replaceDay('2026-10-01', [
      evx('2026-10-01', 1, 'tut', 'u1', params: {'step': 1, 'skipped': 0}),
      evx('2026-10-01', 2, 'tut', 'u2', params: {'step': 2}, platform: 'IOS'),
      evx('2026-10-01', 3, 'stg_start', 'u1', params: {'stg': 1}),
    ]);
    expect(store.paramKeys('tut', '2026-10-01', '2026-10-01'), ['skipped', 'step']);
    expect(store.paramKeys('tut', '2026-10-01', '2026-10-01', platform: 'IOS'), ['step']);
    expect(store.paramKeys('tut', '2026-10-02', '2026-10-03'), isEmpty);
  });
}
