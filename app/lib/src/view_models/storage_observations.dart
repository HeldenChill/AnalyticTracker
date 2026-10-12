import 'package:analytic_shared/analytic_shared.dart';

enum DayAvailability { stored, missing, incomplete, future }

class StoredObservation {
  const StoredObservation({
    required this.day,
    required this.count,
    required this.availability,
    this.updatedAt,
  });

  final String day;
  final int? count;
  final DayAvailability availability;
  final DateTime? updatedAt;
}

DateTime? parseStoredTimestamp(String raw) {
  final m = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})'
    r'(?:\.(\d{1,6}))?(Z|[+-]\d{2}:\d{2})$').firstMatch(raw);
  if (m == null || !isValidDay(m[1]!)) return null;
  if (int.parse(m[2]!) > 23 || int.parse(m[3]!) > 59 || int.parse(m[4]!) > 59) {
    return null;
  }
  final zone = m[6]!;
  if (zone != 'Z' &&
      (int.parse(zone.substring(1, 3)) > 23 ||
          int.parse(zone.substring(4, 6)) > 59)) {
    return null;
  }
  return DateTime.tryParse(raw)?.toUtc();
}

List<StoredObservation> storedObservations(List<DayStat> stored, Filters f,
    {required DateTime now}) {
  if (!isValidDay(f.from) || !isValidDay(f.to) || f.from.compareTo(f.to) > 0) {
    throw ArgumentError('Storage interval must contain valid ascending calendar dates');
  }
  final today = formatDay(DateTime(now.year, now.month, now.day));
  final byDay = {for (final row in stored) row.day: row};
  return [
    for (final day in daysBetween(f.from, f.to))
      StoredObservation(
        day: day,
        count: day.compareTo(today) > 0 ? null : byDay[day]?.rowCount,
        availability: day.compareTo(today) > 0
            ? DayAvailability.future
            : day == today
                ? DayAvailability.incomplete
                : byDay.containsKey(day)
                    ? DayAvailability.stored : DayAvailability.missing,
        updatedAt: parseStoredTimestamp(byDay[day]?.pulledAt ?? ''),
      ),
  ];
}
