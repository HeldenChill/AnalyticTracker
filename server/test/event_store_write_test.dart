import 'dart:io';

import 'package:analytic_server/analytic_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late EventStore store;
  setUp(() => store = EventStore.inMemory());
  tearDown(() => store.close());

  test('replaceDay records rows and pulled day', () {
    store.replaceDay('2026-10-01', [ev('2026-10-01', 1, 'a', 'u1'), ev('2026-10-01', 2, 'b', 'u1')],
        now: DateTime.utc(2026, 10, 2, 1));
    expect(store.pulledDays(), {'2026-10-01'});
    final d = store.days().single;
    expect(d.toJson(), {'day': '2026-10-01', 'rowCount': 2, 'pulledAt': '2026-10-02T01:00:00.000Z'});
    expect(store.rowCount('2026-10-01'), 2);
  });

  test('replaceDay twice keeps second set only', () {
    store.replaceDay('2026-10-01', [ev('2026-10-01', 1, 'a', 'u1'), ev('2026-10-01', 2, 'a', 'u2')]);
    store.replaceDay('2026-10-01', [ev('2026-10-01', 1, 'a', 'u1'), ev('2026-10-01', 2, 'a', 'u2'), ev('2026-10-01', 3, 'a', 'u3')]);
    expect(store.rowCount('2026-10-01'), 3);
    expect(store.days().single.rowCount, 3);
  });

  test('replaceDay with empty list marks day pulled with 0 rows', () {
    store.replaceDay('2026-10-01', const []);
    expect(store.days().single.rowCount, 0);
  });

  test('event from another day rolls back whole write', () {
    store.replaceDay('2026-10-01', [ev('2026-10-01', 1, 'a', 'u1')]);
    expect(
      () => store.replaceDay('2026-10-01', [ev('2026-10-01', 1, 'a', 'u1'), ev('2026-10-02', 2, 'a', 'u1')]),
      throwsArgumentError,
    );
    expect(store.rowCount('2026-10-01'), 1);
    expect(store.days().single.rowCount, 1);
    expect(store.pulledDays(), {'2026-10-01'});
  });

  test('days are sorted ascending', () {
    store.replaceDay('2026-10-03', const []);
    store.replaceDay('2026-10-01', const []);
    expect(store.days().map((d) => d.day), ['2026-10-01', '2026-10-03']);
  });

  test('file db uses WAL and creates parent dirs', () {
    final dir = Directory.systemTemp.createTempSync('at_store_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'nested', 'events.db');
    final fileStore = EventStore.open(path);
    expect(fileStore.journalMode(), 'wal');
    fileStore.replaceDay('2026-10-01', [ev('2026-10-01', 1, 'a', 'u1')]);
    fileStore.close();
    final reopened = EventStore.open(path);
    expect(reopened.rowCount('2026-10-01'), 1);
    reopened.close();
  });
}
