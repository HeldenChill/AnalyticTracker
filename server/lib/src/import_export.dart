import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';

import 'event_store.dart';
import 'raw_event.dart';

/// Parses a BigQuery console "Save results → JSON" export of the manual-export
/// query (columns: day, event_timestamp, event_name, user_pseudo_id, params,
/// props, platform, app_version). Accepts a JSON array or newline-delimited JSON.
Map<String, List<RawEvent>> parseBigQueryExport(String text) {
  final trimmed = text.trimLeft();
  final List<Object?> rows = trimmed.startsWith('[')
      ? jsonDecode(trimmed) as List<Object?>
      : [
          for (final line in const LineSplitter().convert(trimmed))
            if (line.trim().isNotEmpty) jsonDecode(line),
        ];

  final byDay = <String, List<RawEvent>>{};
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    if (r is! Map) throw FormatException('row ${i + 1}: not a JSON object');
    final day = r['day'];
    if (day is! String || !isValidDay(day)) {
      throw FormatException('row ${i + 1}: "day" must be YYYY-MM-DD, got $day');
    }
    final event = rawEventFromCells(day, [
      r['event_timestamp'],
      r['event_name'],
      r['user_pseudo_id'],
      r['params'],
      r['props'],
      r['platform'],
      r['app_version'],
    ]);
    byDay.putIfAbsent(day, () => []).add(event);
  }
  return byDay;
}

/// Imports an export into [store]. Each day in the file replaces that day's
/// rows, so re-importing the same file is safe. Returns rows per day.
Map<String, int> importExport(String text, EventStore store) {
  final byDay = parseBigQueryExport(text);
  final days = byDay.keys.toList()..sort();
  for (final day in days) {
    store.replaceDay(day, byDay[day]!);
  }
  return {for (final d in days) d: byDay[d]!.length};
}
