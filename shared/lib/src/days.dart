final _dayRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _tableRe = RegExp(r'^events_(\d{4})(\d{2})(\d{2})$');

String formatDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _parseUtc(String day) => DateTime.parse('${day}T00:00:00Z');

/// True only for a real calendar date written exactly as YYYY-MM-DD.
bool isValidDay(String s) {
  if (!_dayRe.hasMatch(s)) return false;
  final d = DateTime.tryParse('${s}T00:00:00Z');
  return d != null && formatDay(d) == s;
}

/// Day arithmetic in UTC so DST never shifts the date.
String addDays(String day, int n) =>
    formatDay(_parseUtc(day).add(Duration(days: n)));

String? dayFromTableName(String table) {
  final m = _tableRe.firstMatch(table);
  if (m == null) return null;
  final day = '${m[1]}-${m[2]}-${m[3]}';
  return isValidDay(day) ? day : null;
}

String tableNameFromDay(String day) => 'events_${day.replaceAll('-', '')}';

List<String> daysBetween(String from, String to) {
  final out = <String>[];
  for (var d = from; d.compareTo(to) <= 0; d = addDays(d, 1)) {
    out.add(d);
  }
  return out;
}

List<String> missingDays(Iterable<String> days) {
  final sorted = days.toSet().toList()..sort();
  if (sorted.length < 2) return const [];
  final have = sorted.toSet();
  return daysBetween(sorted.first, sorted.last)
      .where((d) => !have.contains(d))
      .toList();
}
