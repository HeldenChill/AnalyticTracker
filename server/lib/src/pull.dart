import 'package:analytic_shared/analytic_shared.dart';

import 'event_source.dart';
import 'event_store.dart';

class PullResult {
  PullResult(this.pulled, this.failed);
  final List<String> pulled;
  final Map<String, String> failed;
  bool get ok => failed.isEmpty;
}

/// Pulls every available day not yet stored, plus the last [refreshRecentDays]
/// days (BigQuery daily tables still receive late events). Oldest first,
/// because the BigQuery sandbox deletes the oldest tables first (60 days).
Future<PullResult> runPull(
  EventSource source,
  EventStore store, {
  required String today,
  int refreshRecentDays = 3,
  void Function(String) log = print,
}) async {
  final available = await source.listDays();
  final have = store.pulledDays();
  final cutoff = addDays(today, -refreshRecentDays);
  final todo = available
      .where((d) => !have.contains(d) || d.compareTo(cutoff) >= 0)
      .toSet()
      .toList()
    ..sort();

  final pulled = <String>[];
  final failed = <String, String>{};
  for (final day in todo) {
    try {
      final events = await source.fetchDay(day);
      store.replaceDay(day, events);
      pulled.add(day);
      log('pulled $day: ${events.length} rows');
    } catch (e) {
      failed[day] = '$e';
      log('FAILED $day: $e');
    }
  }
  return PullResult(pulled, failed);
}
