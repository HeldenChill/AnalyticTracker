import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

typedef EventsQuery = ({Filters filters, bool compare});

class EventsPayload {
  const EventsPayload({
    required this.current,
    required this.days,
    this.previous,
    this.previousError,
  });

  final List<EventCount> current;
  final List<DayStat> days;
  final List<EventCount>? previous;
  final Object? previousError;
}

final eventsExplorerProvider =
    FutureProvider.family<EventsPayload, EventsQuery>((ref, q) async {
  final api = ref.watch(apiClientProvider);
  final f = q.filters;
  Future<List<EventCount>> load(Filters x) => api.counts(
        x.from,
        x.to,
        platform: x.platform,
        version: x.version,
        includeTest: x.includeTest,
      );

  Object? previousError;
  final previousFuture = q.compare
      ? load(f.previousPeriod()).catchError((Object e) {
          previousError = e;
          return <EventCount>[];
        })
      : Future.value(<EventCount>[]);
  final requiredResults = await Future.wait<Object>([
    load(f),
    ref.watch(daysProvider.future),
  ]);
  final previousRows = await previousFuture;
  return EventsPayload(
    current: requiredResults[0] as List<EventCount>,
    days: requiredResults[1] as List<DayStat>,
    previous: !q.compare || previousError != null ? null : previousRows,
    previousError: previousError,
  );
});

final selectedEventProvider = StateProvider<String?>((ref) => null);
