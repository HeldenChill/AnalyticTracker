/// Formats a table of rows into RFC 4180 CSV text.
String toCsv(List<String> headers, List<List<dynamic>> rows) {
  final buf = StringBuffer();
  buf.write(headers.map(_escapeCsvCell).join(','));
  for (final row in rows) {
    buf.write('\r\n');
    buf.write(row.map(_escapeCsvCell).join(','));
  }
  return buf.toString();
}

String _escapeCsvCell(dynamic value) {
  if (value == null) return '';
  final s = value.toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}
