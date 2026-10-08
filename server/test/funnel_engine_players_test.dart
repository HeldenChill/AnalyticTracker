import 'package:analytic_shared/analytic_shared.dart';
import 'package:analytic_server/src/event_store.dart';
import 'package:analytic_server/src/raw_event.dart';
import 'package:test/test.dart';

void main() {
  late EventStore store;

  setUp(() {
    store = EventStore.inMemory();
  });

  tearDown(() => store.close());

  final def = FunnelDef(
    name: 'Test',
    windowMinutes: 1440,
    steps: const [
      FunnelStepDef(event: 'step1'),
      FunnelStepDef(event: 'step2'),
      FunnelStepDef(event: 'step3'),
    ],
  );

  test('players filter separates converted and dropped correctly', () {
    // p1 reaches step 3
    // p2 reaches step 2 and stops
    // p3 reaches step 1 and stops
    store.replaceDay('2026-10-01', [
      RawEvent(day: '2026-10-01', tsMicros: 100, eventName: 'step1', userPseudoId: 'p1', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
      RawEvent(day: '2026-10-01', tsMicros: 200, eventName: 'step2', userPseudoId: 'p1', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
      RawEvent(day: '2026-10-01', tsMicros: 300, eventName: 'step3', userPseudoId: 'p1', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),

      RawEvent(day: '2026-10-01', tsMicros: 150, eventName: 'step1', userPseudoId: 'p2', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
      RawEvent(day: '2026-10-01', tsMicros: 250, eventName: 'step2', userPseudoId: 'p2', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),

      RawEvent(day: '2026-10-01', tsMicros: 180, eventName: 'step1', userPseudoId: 'p3', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
    ]);

    const f = Filters(from: '2026-10-01', to: '2026-10-01');

    // Step 2 converted: reached >= 2 -> p1, p2
    final conv2 = store.funnelEngine.players(def, f, step: 2, outcome: FunnelPlayerOutcome.converted);
    expect(conv2.total, equals(2));
    expect(conv2.players.map((p) => p.uid).toList(), equals(['p1', 'p2']));

    // Step 2 dropped: reached == 1 -> p3
    final drop2 = store.funnelEngine.players(def, f, step: 2, outcome: FunnelPlayerOutcome.dropped);
    expect(drop2.total, equals(1));
    expect(drop2.players.map((p) => p.uid).toList(), equals(['p3']));

    // Step 3 converted: reached >= 3 -> p1
    final conv3 = store.funnelEngine.players(def, f, step: 3, outcome: FunnelPlayerOutcome.converted);
    expect(conv3.total, equals(1));
    expect(conv3.players.first.uid, equals('p1'));

    // Step 3 dropped: reached == 2 -> p2
    final drop3 = store.funnelEngine.players(def, f, step: 3, outcome: FunnelPlayerOutcome.dropped);
    expect(drop3.total, equals(1));
    expect(drop3.players.first.uid, equals('p2'));
  });

  test('players list ordered by entryTs and limits correctly while returning total', () {
    store.replaceDay('2026-10-01', [
      RawEvent(day: '2026-10-01', tsMicros: 300, eventName: 'step1', userPseudoId: 'p3', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
      RawEvent(day: '2026-10-01', tsMicros: 100, eventName: 'step1', userPseudoId: 'p1', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
      RawEvent(day: '2026-10-01', tsMicros: 200, eventName: 'step1', userPseudoId: 'p2', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
    ]);
    const f = Filters(from: '2026-10-01', to: '2026-10-01');

    final res = store.funnelEngine.players(def, f, step: 2, outcome: FunnelPlayerOutcome.dropped, limit: 2);
    expect(res.total, equals(3));
    expect(res.players, hasLength(2));
    expect(res.players[0].uid, equals('p1'));
    expect(res.players[1].uid, equals('p2'));
  });

  test('players list filters by segment value', () {
    store.replaceDay('2026-10-01', [
      RawEvent(day: '2026-10-01', tsMicros: 100, eventName: 'step1', userPseudoId: 'p1', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
      RawEvent(day: '2026-10-01', tsMicros: 200, eventName: 'step1', userPseudoId: 'p2', paramsJson: '{}', userPropsJson: '{}', platform: 'IOS', appVersion: '1.0'),
    ]);
    const f = Filters(from: '2026-10-01', to: '2026-10-01');
    const breakdown = FunnelBreakdown(by: FunnelBreakdownBy.platform);

    final res = store.funnelEngine.players(
      def,
      f,
      step: 2,
      outcome: FunnelPlayerOutcome.dropped,
      breakdown: breakdown,
      segment: 'IOS',
    );
    expect(res.total, equals(1));
    expect(res.players.first.uid, equals('p2'));
  });
}
