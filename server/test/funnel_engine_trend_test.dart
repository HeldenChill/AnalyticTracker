import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  late EventStore store;

  setUp(() {
    store = EventStore.inMemory();
  });

  tearDown(() => store.close());

  RawEvent ev(String day, String name, int tsMicros, {String user = 'u1', String platform = 'ANDROID', String version = '1.0.0'}) =>
      RawEvent(
        day: day,
        eventName: name,
        tsMicros: tsMicros,
        userPseudoId: user,
        paramsJson: '{}',
        userPropsJson: '{}',
        platform: platform,
        appVersion: version,
      );

  int micros(String day, int hour) =>
      DateTime.parse('${day}T${hour.toString().padLeft(2, '0')}:00:00Z').microsecondsSinceEpoch;

  final def = FunnelDef(
    name: 'Test Funnel',
    windowMinutes: 1440,
    steps: const [
      FunnelStepDef(event: 'step1'),
      FunnelStepDef(event: 'step2'),
    ],
  );

  test('day interval buckets cover all days in range, including empty days', () {
    // Entries on 2026-10-01 and 2026-10-03, none on 2026-10-02
    store.replaceDay('2026-10-01', [
      ev('2026-10-01', 'step1', micros('2026-10-01', 10), user: 'u1'),
      ev('2026-10-01', 'step2', micros('2026-10-01', 11), user: 'u1'),
    ]);
    store.replaceDay('2026-10-02', []);
    store.replaceDay('2026-10-03', [
      ev('2026-10-03', 'step1', micros('2026-10-03', 10), user: 'u2'),
    ]);

    final filters = const Filters(from: '2026-10-01', to: '2026-10-03');
    final res = store.funnelEngine.run(def, filters, interval: FunnelInterval.day);

    expect(res.trend.length, 3);
    expect(res.trend.map((t) => t.start), ['2026-10-01', '2026-10-02', '2026-10-03']);

    // Day 1: 1 entered, 1 completed
    expect(res.trend[0].players, [1, 1]);
    expect(res.trend[0].totalConversion, 1.0);

    // Day 2: empty bucket -> 0 players, null conversion
    expect(res.trend[1].players, [0, 0]);
    expect(res.trend[1].totalConversion, isNull);

    // Day 3: 1 entered, 0 completed
    expect(res.trend[2].players, [1, 0]);
    expect(res.trend[2].totalConversion, 0.0);
  });

  test('incomplete flag set correctly for 1-day window', () {
    // 3-day range: 2026-10-01 to 2026-10-03
    // Day 1 (Oct 1 end = Oct 2 00:00 + 1d = Oct 3 00:00 <= Oct 4 00:00): complete
    // Day 2 (Oct 2 end = Oct 3 00:00 + 1d = Oct 4 00:00 <= Oct 4 00:00): complete
    // Day 3 (Oct 3 end = Oct 4 00:00 + 1d = Oct 5 00:00 > Oct 4 00:00): incomplete
    final filters = const Filters(from: '2026-10-01', to: '2026-10-03');
    final res = store.funnelEngine.run(def, filters, interval: FunnelInterval.day);

    expect(res.trend[0].incomplete, isFalse);
    expect(res.trend[1].incomplete, isFalse);
    expect(res.trend[2].incomplete, isTrue);
  });

  test('whole range window marks only last bucket as incomplete', () {
    final noWindowDef = FunnelDef(
      name: 'No window',
      windowMinutes: null,
      steps: const [FunnelStepDef(event: 'step1'), FunnelStepDef(event: 'step2')],
    );
    final filters = const Filters(from: '2026-10-01', to: '2026-10-03');
    final res = store.funnelEngine.run(noWindowDef, filters, interval: FunnelInterval.day);

    expect(res.trend[0].incomplete, isFalse);
    expect(res.trend[1].incomplete, isFalse);
    expect(res.trend[2].incomplete, isTrue);
  });

  test('week bucket aligns to Monday even when range starts mid-week', () {
    // 2026-10-07 is Wednesday. Monday of that week is 2026-10-05.
    // 2026-10-14 is Wednesday next week. Monday is 2026-10-12.
    store.replaceDay('2026-10-07', [
      ev('2026-10-07', 'step1', micros('2026-10-07', 10), user: 'u1'),
      ev('2026-10-07', 'step2', micros('2026-10-07', 11), user: 'u1'),
    ]);
    store.replaceDay('2026-10-14', [
      ev('2026-10-14', 'step1', micros('2026-10-14', 10), user: 'u2'),
    ]);

    final filters = const Filters(from: '2026-10-07', to: '2026-10-14');
    final res = store.funnelEngine.run(def, filters, interval: FunnelInterval.week);

    expect(res.trend.length, 2);
    expect(res.trend[0].start, '2026-10-05');
    expect(res.trend[0].players, [1, 1]);
    expect(res.trend[1].start, '2026-10-12');
    expect(res.trend[1].players, [1, 0]);
  });

  test('trend and breakdown can be requested together', () {
    store.replaceDay('2026-10-01', [
      ev('2026-10-01', 'step1', micros('2026-10-01', 10), platform: 'ANDROID'),
      ev('2026-10-01', 'step2', micros('2026-10-01', 11), platform: 'ANDROID'),
    ]);

    final filters = const Filters(from: '2026-10-01', to: '2026-10-02');
    final res = store.funnelEngine.run(
      def,
      filters,
      breakdown: const FunnelBreakdown(by: FunnelBreakdownBy.platform),
      interval: FunnelInterval.day,
    );

    expect(res.trend, isNotEmpty);
    expect(res.segments, isNotEmpty);
    expect(res.segments.first.value, 'ANDROID');
  });
}
