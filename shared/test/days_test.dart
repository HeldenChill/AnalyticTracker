import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  group('isValidDay', () {
    test('accepts real dates', () {
      expect(isValidDay('2026-10-05'), isTrue);
      expect(isValidDay('2024-02-29'), isTrue);
    });
    test('rejects malformed or impossible dates', () {
      for (final s in [
        '2026-02-30',
        '2026-13-01',
        '20261005',
        '2026-1-05',
        '',
        '2026-10-05x',
        '2026-10-05T00:00:00Z',
      ]) {
        expect(isValidDay(s), isFalse, reason: s);
      }
    });
  });

  test('formatDay pads fields', () {
    expect(formatDay(DateTime(2026, 3, 7)), '2026-03-07');
  });

  group('addDays', () {
    test('crosses month, year and DST boundaries', () {
      expect(addDays('2026-10-05', 1), '2026-10-06');
      expect(addDays('2026-03-01', -1), '2026-02-28');
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2026-10-25', 1), '2026-10-26');
      expect(addDays('2026-03-29', 1), '2026-03-30');
    });
  });

  group('table names', () {
    test('dayFromTableName parses daily tables only', () {
      expect(dayFromTableName('events_20261005'), '2026-10-05');
      expect(dayFromTableName('events_intraday_20261005'), isNull);
      expect(dayFromTableName('events_20261399'), isNull);
      expect(dayFromTableName('pseudonymous_users_20261005'), isNull);
    });
    test('tableNameFromDay', () {
      expect(tableNameFromDay('2026-10-05'), 'events_20261005');
    });
  });

  group('daysBetween', () {
    test('inclusive ascending', () {
      expect(daysBetween('2026-09-29', '2026-10-02'),
          ['2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02']);
    });
    test('single day', () {
      expect(daysBetween('2026-10-01', '2026-10-01'), ['2026-10-01']);
    });
    test('empty when from after to', () {
      expect(daysBetween('2026-10-02', '2026-10-01'), isEmpty);
    });
  });

  group('missingDays', () {
    test('finds gaps regardless of input order', () {
      expect(missingDays(['2026-10-01', '2026-10-04', '2026-10-02']),
          ['2026-10-03']);
    });
    test('empty for fewer than two days', () {
      expect(missingDays([]), isEmpty);
      expect(missingDays(['2026-10-01']), isEmpty);
    });
  });
}
