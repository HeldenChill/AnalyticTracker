import 'package:analytic_server/analytic_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

class FakeSource implements EventSource {
  FakeSource(this.data, {Set<String>? failDays}) : failDays = failDays ?? {};
  final Map<String, List<RawEvent>> data;
  final Set<String> failDays;
  final fetched = <String>[];

  @override
  Future<List<String>> listDays() async => data.keys.toList()..sort();

  @override
  Future<List<RawEvent>> fetchDay(String day) async {
    fetched.add(day);
    if (failDays.contains(day)) throw StateError('boom $day');
    return data[day]!;
  }
}

Map<String, List<RawEvent>> daysData(List<String> days) =>
    {for (final d in days) d: [ev(d, 1, 'a', 'u1'), ev(d, 2, 'b', 'u1')]};

void main() {
  late EventStore store;
  setUp(() => store = EventStore.inMemory());
  tearDown(() => store.close());
  void quiet(String _) {}

  test('empty store pulls every day oldest first', () async {
    final src = FakeSource(daysData(['2026-10-03', '2026-09-01', '2026-10-01']));
    final r = await runPull(src, store, today: '2026-12-01', log: quiet);
    expect(src.fetched, ['2026-09-01', '2026-10-01', '2026-10-03']);
    expect(r.pulled, ['2026-09-01', '2026-10-01', '2026-10-03']);
    expect(r.ok, isTrue);
    expect(store.pulledDays(), {'2026-09-01', '2026-10-01', '2026-10-03'});
  });

  test('skips pulled old days, re-pulls recent days', () async {
    store.replaceDay('2026-09-01', const []);
    store.replaceDay('2026-10-04', const []);
    final src = FakeSource(daysData(['2026-09-01', '2026-09-02', '2026-10-04']));
    await runPull(src, store, today: '2026-10-06', log: quiet);
    expect(src.fetched, ['2026-09-02', '2026-10-04']);
    expect(store.rowCount('2026-10-04'), 2);
  });

  test('re-pulls recent days without duplicates', () async {
    final src = FakeSource(daysData(['2026-10-05']));
    await runPull(src, store, today: '2026-10-06', log: quiet);
    await runPull(src, store, today: '2026-10-06', log: quiet);
    expect(src.fetched, ['2026-10-05', '2026-10-05']);
    expect(store.rowCount('2026-10-05'), 2);
  });

  test('failure on one day does not block others; retried next run', () async {
    final data = daysData(['2026-10-01', '2026-10-02', '2026-10-03']);
    final failing = FakeSource(data, failDays: {'2026-10-02'});
    final r1 = await runPull(failing, store, today: '2026-12-01', log: quiet);
    expect(r1.pulled, ['2026-10-01', '2026-10-03']);
    expect(r1.failed.keys, ['2026-10-02']);
    expect(r1.failed['2026-10-02'], contains('boom'));
    expect(r1.ok, isFalse);
    expect(store.pulledDays(), {'2026-10-01', '2026-10-03'});

    final healthy = FakeSource(data);
    final r2 = await runPull(healthy, store, today: '2026-12-01', log: quiet);
    expect(healthy.fetched, ['2026-10-02']);
    expect(r2.ok, isTrue);
  });

  test('event from wrong day counts as failure, not crash', () async {
    final src = FakeSource({'2026-10-01': [ev('2026-10-02', 1, 'a', 'u1')]});
    final r = await runPull(src, store, today: '2026-12-01', log: quiet);
    expect(r.failed.keys, ['2026-10-01']);
    expect(store.pulledDays(), isEmpty);
  });
}
