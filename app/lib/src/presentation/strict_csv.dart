class CsvRecord {
  const CsvRecord(this.number, this.cells);
  final int number;
  final List<String> cells;
}

/// Strict comma/quote parser. Records, not physical lines, own locations.
List<CsvRecord> parseStrictCsv(String text) {
  final records = <CsvRecord>[];
  var cells = <String>[];
  var field = StringBuffer();
  var state = 0; // 0=start, 1=unquoted, 2=quoted, 3=after quote
  void cell() {
    cells.add(field.toString());
    field = StringBuffer();
    state = 0;
  }

  void row() {
    cell();
    records.add(CsvRecord(records.length + 1, List.unmodifiable(cells)));
    cells = [];
  }

  Never error(String message) =>
      throw FormatException('Record ${records.length + 1}: $message');
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (state == 2) {
      if (ch == '"') {
        state = 3;
      } else {
        field.write(ch);
      }
      continue;
    }
    if (state == 3 && ch == '"') {
      field.write('"');
      state = 2;
      continue;
    }
    if (ch == ',') {
      cell();
      continue;
    }
    if (ch == '\n' || ch == '\r') {
      row();
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      continue;
    }
    if (state == 3) error('Character after closing quote');
    if (ch == '"') {
      if (state != 0) error('Quote inside unquoted field');
      state = 2;
    } else {
      field.write(ch);
      state = 1;
    }
  }
  if (state == 2) error('Unterminated quoted field');
  if (state != 0 || cells.isNotEmpty || field.isNotEmpty) row();
  return List.unmodifiable(records);
}
