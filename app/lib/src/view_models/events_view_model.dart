import 'package:analytic_shared/analytic_shared.dart';
import '../widgets/charts/chart_models.dart';
import 'storage_observations.dart';

enum ChangeKind { percent, newActivity, unchanged, unavailable }

class EventChange {
  const EventChange(this.kind, {this.fraction});

  final ChangeKind kind;
  final double? fraction;
}

class EventRowSummary {
  const EventRowSummary({
    required this.name,
    required this.current,
    required this.previous,
    required this.share,
    required this.change,
    required this.daily,
  });

  final String name;
  final int current;
  final int? previous;
  final double share;
  final EventChange change;
  final List<ChartPoint> daily;
}

class EventSummary {
  const EventSummary({
    required this.total,
    required this.previousTotal,
    required this.distinctNames,
    required this.storedDayCount,
    required this.averagePerStoredDay,
    required this.peakDay,
    required this.peakCount,
    required this.currentSeries,
    required this.previousSeries,
    required this.rows,
    required this.comparisonAvailable,
    required this.missingDays,
  });

  final int total, distinctNames, storedDayCount;
  final int? previousTotal;
  final double? averagePerStoredDay;
  final String? peakDay;
  final int? peakCount;
  final List<ChartPoint> currentSeries, previousSeries;
  final List<EventRowSummary> rows;
  final bool comparisonAvailable;
  final List<String> missingDays;
}

EventChange eventChange(int current, int? previous, {required bool comparable}) {
  if (!comparable || previous == null) {
    return const EventChange(ChangeKind.unavailable);
  }
  if (previous == 0) {
    return EventChange(current == 0 ? ChangeKind.unchanged : ChangeKind.newActivity);
  }
  return EventChange(ChangeKind.percent, fraction: (current - previous) / previous);
}

EventSummary buildEventSummary({
  required List<EventCount> current,
  List<EventCount>? previous,
  required List<DayStat> stored,
  required Filters filters,
  required DateTime now,
}) {
  final currObs = storedObservations(stored, filters, now: now);
  final currDays = [for (final o in currObs) o.day];
  final currDaysSet = currDays.toSet();

  final prevFilters = filters.previousPeriod();
  final prevObs = previous != null
      ? storedObservations(stored, prevFilters, now: now)
      : const <StoredObservation>[];
  final prevDays = [for (final o in prevObs) o.day];
  final prevDaysSet = prevDays.toSet();

  final filteredCurrent = [
    for (final c in current)
      if (currDaysSet.contains(c.day)) c,
  ];

  final filteredPrevious = previous != null
      ? [
          for (final c in previous)
            if (prevDaysSet.contains(c.day)) c,
        ]
      : null;

  final missingDays = [
    for (final o in currObs)
      if (o.availability == DayAvailability.missing) o.day,
  ];

  final storedCurrDays = {
    for (final o in currObs)
      if (o.availability == DayAvailability.stored ||
          (o.availability == DayAvailability.incomplete && o.count != null))
        o.day: o,
  };
  final storedDayCount = storedCurrDays.length;

  final currCountsByDay = <String, int>{};
  final currCountsByName = <String, int>{};
  final currCountsByNameAndDay = <String, Map<String, int>>{};

  for (final c in filteredCurrent) {
    currCountsByDay[c.day] = (currCountsByDay[c.day] ?? 0) + c.count;
    currCountsByName[c.eventName] = (currCountsByName[c.eventName] ?? 0) + c.count;
    final map = currCountsByNameAndDay.putIfAbsent(c.eventName, () => <String, int>{});
    map[c.day] = (map[c.day] ?? 0) + c.count;
  }

  final total = filteredCurrent.fold<int>(0, (sum, c) => sum + c.count);
  final distinctNames = currCountsByName.values.where((c) => c > 0).length;
  final averagePerStoredDay =
      storedDayCount > 0 ? (total / storedDayCount) : null;

  String? peakDay;
  int? peakCount;

  if (storedCurrDays.isNotEmpty) {
    int maxCount = -1;
    for (final day in currDays) {
      if (storedCurrDays.containsKey(day)) {
        final count = currCountsByDay[day] ?? 0;
        if (count > maxCount) {
          maxCount = count;
          peakDay = day;
          peakCount = count;
        }
      }
    }
  }

  final currentSeries = [
    for (int i = 0; i < currObs.length; i++)
      ChartPoint(
        i.toDouble(),
        storedCurrDays.containsKey(currObs[i].day)
            ? (currCountsByDay[currObs[i].day] ?? 0).toDouble()
            : null,
        label: currObs[i].day,
        incomplete: currObs[i].availability == DayAvailability.incomplete,
      ),
  ];

  final prevCountsByDay = <String, int>{};
  final prevCountsByName = <String, int>{};

  if (filteredPrevious != null) {
    for (final c in filteredPrevious) {
      prevCountsByDay[c.day] = (prevCountsByDay[c.day] ?? 0) + c.count;
      prevCountsByName[c.eventName] = (prevCountsByName[c.eventName] ?? 0) + c.count;
    }
  }

  final int? previousTotal =
      filteredPrevious?.fold<int>(0, (sum, c) => sum + c.count);

  final storedPrevDays = {
    for (final o in prevObs)
      if (o.availability == DayAvailability.stored ||
          (o.availability == DayAvailability.incomplete && o.count != null))
        o.day: o,
  };

  final previousSeries = [
    if (filteredPrevious != null)
      for (int i = 0; i < prevObs.length; i++)
        ChartPoint(
          i.toDouble(),
          storedPrevDays.containsKey(prevObs[i].day)
              ? (prevCountsByDay[prevObs[i].day] ?? 0).toDouble()
              : null,
          label: prevObs[i].day,
          incomplete: prevObs[i].availability == DayAvailability.incomplete,
        ),
  ];

  final bool comparisonAvailable = previous != null &&
      currDays.isNotEmpty &&
      currDays.length == prevDays.length &&
      currObs.every((o) => o.availability == DayAvailability.stored) &&
      prevObs.every((o) => o.availability == DayAvailability.stored);

  final bool prevFullyStored = prevObs.isNotEmpty &&
      prevObs.every((o) => o.availability == DayAvailability.stored);

  final allNames = <String>{
    ...currCountsByName.keys,
    if (filteredPrevious != null) ...prevCountsByName.keys,
  };

  final rows = <EventRowSummary>[];
  for (final name in allNames) {
    final cur = currCountsByName[name] ?? 0;
    final share = total > 0 ? (cur / total) : 0.0;
    final int? prev;
    if (previous == null) {
      prev = null;
    } else if (prevCountsByName.containsKey(name)) {
      prev = prevCountsByName[name]!;
    } else {
      prev = prevFullyStored ? 0 : null;
    }

    final change = eventChange(cur, prev, comparable: comparisonAvailable);
    final byDay = currCountsByNameAndDay[name] ?? const <String, int>{};

    final daily = [
      for (int i = 0; i < currObs.length; i++)
        ChartPoint(
          i.toDouble(),
          storedCurrDays.containsKey(currObs[i].day)
              ? (byDay[currObs[i].day] ?? 0).toDouble()
              : null,
          label: currObs[i].day,
          incomplete: currObs[i].availability == DayAvailability.incomplete,
        ),
    ];

    rows.add(EventRowSummary(
      name: name,
      current: cur,
      previous: prev,
      share: share,
      change: change,
      daily: daily,
    ));
  }

  rows.sort((a, b) {
    final c = b.current.compareTo(a.current);
    if (c != 0) return c;
    return a.name.compareTo(b.name);
  });

  return EventSummary(
    total: total,
    previousTotal: previousTotal,
    distinctNames: distinctNames,
    storedDayCount: storedDayCount,
    averagePerStoredDay: averagePerStoredDay,
    peakDay: peakDay,
    peakCount: peakCount,
    currentSeries: currentSeries,
    previousSeries: previousSeries,
    rows: rows,
    comparisonAvailable: comparisonAvailable,
    missingDays: missingDays,
  );
}
