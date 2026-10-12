import 'package:analytic_shared/analytic_shared.dart';

import 'storage_observations.dart';

class DataHealthViewModel {
  const DataHealthViewModel({
    required this.timeline,
    required this.totalEvents,
    required this.storedDaysCount,
    required this.completedExpectedDays,
    required this.completedStoredDays,
    required this.missingDays,
    required this.latestStoredDay,
    required this.latestUpdate,
  });

  final List<StoredObservation> timeline;
  final int totalEvents, storedDaysCount, completedExpectedDays, completedStoredDays;
  final List<String> missingDays;
  final String? latestStoredDay;
  final DateTime? latestUpdate;

  double? get coverage => completedExpectedDays == 0
      ? null
      : completedStoredDays / completedExpectedDays;
}

DataHealthViewModel buildDataHealth(List<DayStat> stored, Filters f,
    {required DateTime now}) {
  final timeline = storedObservations(stored, f, now: now);
  final today = formatDay(DateTime(now.year, now.month, now.day));

  var completedExpectedDays = 0;
  var completedStoredDays = 0;
  final missingDays = <String>[];
  var totalEvents = 0;

  for (final obs in timeline) {
    if (obs.count != null) {
      totalEvents += obs.count!;
    }
    if (obs.day.compareTo(today) < 0) {
      completedExpectedDays++;
      if (obs.availability == DayAvailability.stored) {
        completedStoredDays++;
      } else if (obs.availability == DayAvailability.missing) {
        missingDays.add(obs.day);
      }
    }
  }

  final storedDaysCount = timeline.where((o) => o.count != null).length;

  String? latestStoredDay;
  if (stored.isNotEmpty) {
    latestStoredDay = stored.map((r) => r.day).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
  }

  DateTime? latestUpdate;
  for (final row in stored) {
    final parsed = parseStoredTimestamp(row.pulledAt);
    if (parsed != null) {
      if (latestUpdate == null || parsed.isAfter(latestUpdate)) {
        latestUpdate = parsed;
      }
    }
  }

  return DataHealthViewModel(
    timeline: timeline,
    totalEvents: totalEvents,
    storedDaysCount: storedDaysCount,
    completedExpectedDays: completedExpectedDays,
    completedStoredDays: completedStoredDays,
    missingDays: missingDays,
    latestStoredDay: latestStoredDay,
    latestUpdate: latestUpdate,
  );
}
