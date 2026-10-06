import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';
const d2 = '2026-10-02';

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    store.replaceDay(d1, [
      evx(d1, 1, 'first_open', 'u1'),
      evx(d1, 2, 'stg_start', 'u1', params: {'stg': 1}),
      evx(d1, 3, 'first_open', 'u2', platform: 'IOS'),
    ]);
    store.replaceDay(d2, [evx(d2, 4, 'session_start', 'u1')]);
    handler = buildHandler(store);
  });
  tearDown(() => store.close());

  Future<(int, Object?)> getJson(String path) async {
    final res = await handler(Request('GET', Uri.parse('http://localhost$path')));
    return (res.statusCode, jsonDecode(await res.readAsString()));
  }

  test('GET /filters', () async {
    final (status, body) = await getJson('/filters');
    expect(status, 200);
    expect(body, {'platforms': ['ANDROID', 'IOS'], 'versions': ['1.0.0']});
  });

  test('GET /overview with platform', () async {
    final (status, body) = await getJson('/overview?from=$d1&to=$d2&platform=IOS');
    expect(status, 200);
    final m = body as Map;
    expect(m['kpis']['newUsers'], 1);
    expect((m['daily'] as List).length, 2);
    expect(m['previous'], isNull);
  });

  test('GET /retention', () async {
    final (status, body) = await getJson('/retention?from=$d1&to=$d2');
    expect(status, 200);
    final m = body as Map;
    expect(m['offsets'], [1, 3, 7, 14, 30]);
    expect(m['lastDataDay'], d2);
    expect((m['cohorts'] as List).map((c) => c['day']), [d1]);
    expect((m['cohorts'] as List).single['retained'], [1, null, null, null, null]);
  });

  test('GET /progression', () async {
    final (status, body) = await getJson('/progression?from=$d1&to=$d2');
    expect(status, 200);
    expect(((body as Map)['stages'] as List).single['stage'], 1);
  });

  test('v1 count honours platform filter', () async {
    final (status, body) = await getJson('/events/count?from=$d1&to=$d2&platform=IOS');
    expect(status, 200);
    expect(body, [
      {'day': d1, 'eventName': 'first_open', 'count': 1},
    ]);
  });

  test('v1 funnel honours version filter', () async {
    final (status, body) = await getJson('/funnel?steps=first_open&from=$d1&to=$d2&version=9.9');
    expect(status, 200);
    expect(body, [
      {'eventName': 'first_open', 'users': 0},
    ]);
  });

  group('dashboard routes reject bad ranges', () {
    for (final route in ['/overview', '/retention', '/progression']) {
      for (final q in ['', '?from=$d1', '?from=$d2&to=$d1', '?from=bad&to=$d1']) {
        test('$route$q', () async {
          final (status, body) = await getJson('$route$q');
          expect(status, 400);
          expect((body as Map)['error'], isA<String>());
        });
      }
    }
  });

  test('blank platform param means all', () async {
    final (status, body) = await getJson('/overview?from=$d1&to=$d1&platform=');
    expect(status, 200);
    expect((body as Map)['kpis']['newUsers'], 2);
  });
}
