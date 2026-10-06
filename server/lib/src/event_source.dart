import 'raw_event.dart';

abstract interface class EventSource {
  /// ISO days (YYYY-MM-DD) that have a finished daily table, any order.
  Future<List<String>> listDays();

  /// All events of one day. Every returned event has `day == day`.
  Future<List<RawEvent>> fetchDay(String day);
}
