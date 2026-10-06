import 'dart:convert';

/// Converts BigQuery `TO_JSON_STRING(event_params)` (array of
/// `{key, value: {string_value, int_value, float_value, double_value}}`)
/// into a flat JSON object `{"key": value}`.
String flattenParams(String? bqJson) {
  if (bqJson == null || bqJson.isEmpty) return '{}';
  final Object? decoded;
  try {
    decoded = jsonDecode(bqJson);
  } on FormatException {
    return '{}';
  }
  if (decoded is! List) return '{}';
  final out = <String, Object?>{};
  for (final item in decoded) {
    if (item is! Map) continue;
    final key = item['key'];
    if (key is! String) continue;
    out[key] = _pickValue(item['value']);
  }
  return jsonEncode(out);
}

Object? _pickValue(Object? v) {
  if (v is! Map) return null;
  final s = v['string_value'];
  if (s != null) return s;
  final i = v['int_value'];
  if (i != null) return i is String ? (int.tryParse(i) ?? i) : i;
  final d = v['double_value'] ?? v['float_value'];
  if (d != null) return d is String ? (double.tryParse(d) ?? d) : d;
  return null;
}
