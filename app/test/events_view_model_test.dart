import 'package:analytic_app/src/view_models/events_view_model.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('volume shares and average use actual stored observations', () {
    final r = buildEventSummary(
      current: const [
        EventCount(day: '2026-10-01', eventName: 'pet_buy', count: 5),
        EventCount(day: '2026-10-01', eventName: 'level_1_fail', count: 1),
        EventCount(day: '2026-10-03', eventName: 'level_1_fail', count: 2),
      ],
      stored: const [
        DayStat(day: '2026-10-01', rowCount: 6, pulledAt: '2026-10-02T01:00:00Z'),
        DayStat(day: '2026-10-02', rowCount: 0, pulledAt: '2026-10-03T01:00:00Z'),
        DayStat(day: '2026-10-03', rowCount: 2, pulledAt: '2026-10-04T01:00:00Z'),
      ],
      filters: const Filters(from: '2026-10-01', to: '2026-10-04'),
      now: DateTime(2026, 10, 10),
    );
    expect(r.total, 8);
    expect(r.distinctNames, 2);
    expect(r.storedDayCount, 3);
    expect(r.averagePerStoredDay, closeTo(8 / 3, 1e-12));
    expect(r.peakDay, '2026-10-01');
    expect(r.peakCount, 6);
    expect(r.currentSeries.map((p) => p.value), [6.0, 0.0, 2.0, null]);
    final pet = r.rows.firstWhere((row) => row.name == 'pet_buy');
    expect(pet.share, 0.625);
    expect(pet.daily.map((p) => p.value), [5.0, 0.0, 0.0, null]);
    expect(r.comparisonAvailable, isFalse);
    expect(r.missingDays, ['2026-10-04']);
  });

  test('zero and unavailable comparisons have explicit meanings', () {
    expect(eventChange(5, 0, comparable: true).kind, ChangeKind.newActivity);
    expect(eventChange(0, 0, comparable: true).kind, ChangeKind.unchanged);
    expect(eventChange(15, 10, comparable: true).fraction, 0.5);
    expect(eventChange(0, 10, comparable: true).fraction, -1);
    expect(eventChange(5, null, comparable: false).kind, ChangeKind.unavailable);
  });

  test('same-length previous period retains all gameplay filters', () {
    const f = Filters(
      from: '2026-10-01',
      to: '2026-10-04',
      platform: 'IOS',
      version: '2.0',
      includeTest: true,
    );
    expect(f.previousPeriod().toQuery(), {
      'from': '2026-09-27',
      'to': '2026-09-30',
      'platform': 'IOS',
      'version': '2.0',
      'test': '1',
    });
  });

  test('previous-only name aggregates into previous total with legitimate -100% change', () {
    final r = buildEventSummary(
      current: const [
        EventCount(day: '2026-10-01', eventName: 'pet_buy', count: 5),
      ],
      previous: const [
        EventCount(day: '2026-09-27', eventName: 'pet_buy', count: 4),
        EventCount(day: '2026-09-28', eventName: 'discontinued_event', count: 3),
      ],
      stored: const [
        DayStat(day: '2026-09-27', rowCount: 4, pulledAt: '2026-09-28T01:00:00Z'),
        DayStat(day: '2026-09-28', rowCount: 3, pulledAt: '2026-09-29T01:00:00Z'),
        DayStat(day: '2026-09-29', rowCount: 0, pulledAt: '2026-09-30T01:00:00Z'),
        DayStat(day: '2026-09-30', rowCount: 0, pulledAt: '2026-10-01T01:00:00Z'),
        DayStat(day: '2026-10-01', rowCount: 5, pulledAt: '2026-10-02T01:00:00Z'),
        DayStat(day: '2026-10-02', rowCount: 0, pulledAt: '2026-10-03T01:00:00Z'),
        DayStat(day: '2026-10-03', rowCount: 0, pulledAt: '2026-10-04T01:00:00Z'),
        DayStat(day: '2026-10-04', rowCount: 0, pulledAt: '2026-10-05T01:00:00Z'),
      ],
      filters: const Filters(from: '2026-10-01', to: '2026-10-04'),
      now: DateTime(2026, 10, 10),
    );

    expect(r.total, 5);
    expect(r.previousTotal, 7);
    expect(r.distinctNames, 1);
    expect(r.comparisonAvailable, isTrue);

    final discontinued = r.rows.firstWhere((row) => row.name == 'discontinued_event');
    expect(discontinued.current, 0);
    expect(discontinued.share, 0.0);
    expect(discontinued.previous, 3);
    expect(discontinued.change.kind, ChangeKind.percent);
    expect(discontinued.change.fraction, -1.0);

    final pet = r.rows.firstWhere((row) => row.name == 'pet_buy');
    expect(pet.current, 5);
    expect(pet.share, 1.0);
    expect(pet.previous, 4);
    expect(pet.change.kind, ChangeKind.percent);
    expect(pet.change.fraction, 0.25);
  });

  test('today stored observation is incomplete and disables comparison percentage badges', () {
    final r = buildEventSummary(
      current: const [
        EventCount(day: '2026-10-01', eventName: 'pet_buy', count: 5),
      ],
      previous: const [
        EventCount(day: '2026-09-30', eventName: 'pet_buy', count: 4),
      ],
      stored: const [
        DayStat(day: '2026-09-30', rowCount: 4, pulledAt: '2026-10-01T01:00:00Z'),
        DayStat(day: '2026-10-01', rowCount: 5, pulledAt: '2026-10-01T12:00:00Z'),
      ],
      filters: const Filters(from: '2026-10-01', to: '2026-10-01'),
      now: DateTime(2026, 10, 1, 15, 0),
    );

    expect(r.comparisonAvailable, isFalse);
    expect(r.currentSeries.first.incomplete, isTrue);
  });

  test('zero totals handle shares gracefully without NaN', () {
    final r = buildEventSummary(
      current: const [],
      stored: const [
        DayStat(day: '2026-10-01', rowCount: 0, pulledAt: '2026-10-02T01:00:00Z'),
      ],
      filters: const Filters(from: '2026-10-01', to: '2026-10-01'),
      now: DateTime(2026, 10, 10),
    );
    expect(r.total, 0);
    expect(r.distinctNames, 0);
    expect(r.peakCount, 0);
    expect(r.peakDay, '2026-10-01');
    expect(r.rows, isEmpty);
  });
}
