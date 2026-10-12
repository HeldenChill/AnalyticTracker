import 'package:analytic_app/src/view_models/data_health_view_model.dart';
import 'package:analytic_app/src/view_models/storage_observations.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored zero counts toward coverage while missing does not', () {
    const rows = [
      DayStat(day: '2026-10-03', rowCount: 0, pulledAt: '2026-10-04T01:00:00Z'),
      DayStat(day: '2026-10-01', rowCount: 12, pulledAt: '2026-10-02T01:00:00Z'),
    ];
    final m = buildDataHealth(rows,
      const Filters(from: '2026-10-01', to: '2026-10-04'),
      now: DateTime(2026, 10, 10));
    expect(m.totalEvents, 12);
    expect(m.storedDaysCount, 2);
    expect(m.completedExpectedDays, 4);
    expect(m.completedStoredDays, 2);
    expect(m.coverage, 0.5);
    expect(m.missingDays, ['2026-10-02', '2026-10-04']);
    expect(m.timeline.map((d) => d.count), [12, null, 0, null]);
    expect(m.timeline[2].availability, DayAvailability.stored);
    expect(m.latestStoredDay, '2026-10-03');
    expect(m.latestUpdate, DateTime.utc(2026, 10, 4, 1));
  });
  test('today and future dates do not inflate completed coverage', () {
    final m = buildDataHealth(const [
      DayStat(day: '2026-10-09', rowCount: 3, pulledAt: '2026-10-09T01:00:00Z'),
    ], const Filters(from: '2026-10-08', to: '2026-10-10'),
      now: DateTime(2026, 10, 9, 12));
    expect(m.completedExpectedDays, 1);
    expect(m.completedStoredDays, 0);
    expect(m.missingDays, ['2026-10-08']);
    expect(m.totalEvents, 3);
    expect(m.timeline[1].availability, DayAvailability.incomplete);
    expect(m.timeline[1].count, 3);
    expect(m.timeline[2].availability, DayAvailability.future);
    expect(m.timeline[2].count, isNull);
  });
  test('global freshness is independent of displayed interval and filters', () {
    final m = buildDataHealth(const [
      DayStat(day: '2026-10-01', rowCount: 12, pulledAt: '2026-10-05T09:00:00Z'),
      DayStat(day: '2026-10-08', rowCount: 20, pulledAt: '2026-10-08T09:00:00Z'),
    ], const Filters(from: '2026-10-01', to: '2026-10-02', platform: 'IOS',
      version: 'unknown', includeTest: false), now: DateTime(2026, 10, 9));
    expect(m.totalEvents, 12);
    expect(m.latestStoredDay, '2026-10-08');
    expect(m.latestUpdate, DateTime.utc(2026, 10, 8, 9));
  });
  test('invalid legacy timestamps remain unknown without losing counts', () {
    final m = buildDataHealth(const [
      DayStat(day: '2026-10-01', rowCount: 4, pulledAt: 'a'),
    ], const Filters(from: '2026-10-01', to: '2026-10-01'),
      now: DateTime(2026, 10, 9));
    expect(m.totalEvents, 4);
    expect(m.latestUpdate, isNull);
  });
  test('invalid or ambiguous timestamps stay unknown while counts survive', () {
    for (final raw in ['a', '2026-10-01', '2026-10-01T01:00:00',
      '2026-02-30T01:00:00Z', '2026-10-01T25:00:00Z']) {
      expect(parseStoredTimestamp(raw), isNull);
      final model = buildDataHealth([DayStat(day: '2026-10-01', rowCount: 4, pulledAt: raw)],
        const Filters(from: '2026-10-01', to: '2026-10-01'), now: DateTime(2026, 10, 9));
      expect(model.totalEvents, 4);
      expect(model.completedStoredDays, 1);
      expect(model.latestUpdate, isNull);
    }
  });
  test('global freshness orders real instants and ignores malformed newer text', () {
    final model = buildDataHealth(const [
      DayStat(day: '2026-10-01', rowCount: 1, pulledAt: '2026-10-08T23:30:00-07:00'),
      DayStat(day: '2026-10-02', rowCount: 2, pulledAt: '2026-10-09T06:00:00Z'),
      DayStat(day: '2026-10-08', rowCount: 3, pulledAt: '2026-13-99T01:00:00Z'),
    ], const Filters(from: '2026-10-01', to: '2026-10-02'), now: DateTime(2026, 10, 10));
    expect(model.latestUpdate, DateTime.utc(2026, 10, 9, 6, 30));
    expect(model.latestStoredDay, '2026-10-08');
    expect(model.totalEvents, 3);
  });
  test('zero completed days has unknown coverage rather than zero failure', () {
    final model = buildDataHealth(const [],
      const Filters(from: '2026-10-09', to: '2026-10-10'), now: DateTime(2026, 10, 9));
    expect(model.completedExpectedDays, 0);
    expect(model.coverage, isNull);
    expect(model.missingDays, isEmpty);
    expect(model.timeline.map((p) => p.availability),
      [DayAvailability.incomplete, DayAvailability.future]);
    expect(model.timeline.every((p) => p.count == null), isTrue);
  });
  test('invalid or reversed display intervals fail before day enumeration', () {
    for (final f in [
      const Filters(from: '2026-02-30', to: '2026-03-01'),
      const Filters(from: '2026-10-10', to: '2026-10-01'),
    ]) {
      expect(() => storedObservations(const [], f, now: DateTime(2026, 10, 10)),
        throwsArgumentError);
    }
  });
}
