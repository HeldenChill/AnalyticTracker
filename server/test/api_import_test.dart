import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Map<String, Object?> row(String day, String ts, String name) => {
      'day': day,
      'event_timestamp': ts,
      'event_name': name,
      'user_pseudo_id': 'u1',
      'params': '[]',
      'props': null,
      'platform': 'ANDROID',
      'app_version': '1.0.0',
    };

/// Export with 2 rows on 2026-10-01 and 1 row on 2026-10-02.
final exportText = jsonEncode([
  row('2026-10-01', '1', 'first_open'),
  row('2026-10-01', '2', 'session_start'),
  row('2026-10-02', '3', 'session_start'),
]);

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    // 2026-10-01 already holds 3 rows; 2026-10-02 holds none.
    store.replaceDay('2026-10-01', [
      ev('2026-10-01', 10, 'a', 'x'),
      ev('2026-10-01', 11, 'b', 'x'),
      ev('2026-10-01', 12, 'c', 'x'),
    ]);
    handler = buildHandler(store);
  });
  tearDown(() => store.close());

  Future<(int, Object?)> post(String path, String body) async {
    final res = await handler(Request('POST', Uri.parse('http://localhost$path'), body: body));
    final text = await res.readAsString();
    return (res.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  test('dry run reports rows vs stored and changes nothing', () async {
    final (status, body) = await post('/import?dryRun=1', exportText);
    expect(status, 200);
    expect(body, [
      {'day': '2026-10-01', 'rows': 2, 'stored': 3},
      {'day': '2026-10-02', 'rows': 1, 'stored': 0},
    ]);
    expect(store.rowCount('2026-10-01'), 3);
    expect(store.rowCount('2026-10-02'), 0);
    expect(store.pulledDays(), {'2026-10-01'});
  });

  test('apply replaces each day in the file and is idempotent', () async {
    final (status, body) = await post('/import', exportText);
    expect(status, 200);
    expect(body, {'2026-10-01': 2, '2026-10-02': 1});
    expect(store.rowCount('2026-10-01'), 2);
    expect(store.rowCount('2026-10-02'), 1);

    final (again, _) = await post('/import', exportText);
    expect(again, 200);
    expect(store.rowCount('2026-10-01'), 2);
    expect(store.rowCount('2026-10-02'), 1);
  });

  test('empty and whitespace bodies are 400', () async {
    for (final b in ['', '   \n']) {
      final (status, body) = await post('/import', b);
      expect(status, 400);
      expect((body as Map)['error'], 'Request body must be a BigQuery export');
    }
  });

  test('malformed export is 400 with the parse message and stores nothing', () async {
    final (s1, b1) = await post('/import', 'not json');
    expect(s1, 400);
    expect((b1 as Map)['error'], isA<String>());

    final (s2, b2) = await post('/import?dryRun=1', jsonEncode([row('2026-13-01', '1', 'x')]));
    expect(s2, 400);
    expect((b2 as Map)['error'], contains('"day" must be YYYY-MM-DD'));

    // One bad row anywhere rejects the whole file before any day is replaced.
    final (s3, _) = await post('/import', jsonEncode([row('2026-10-01', '1', 'x'), row('2026-10-02', 'oops', 'y')]));
    expect(s3, 400);
    expect(store.rowCount('2026-10-01'), 3);
  });
}
