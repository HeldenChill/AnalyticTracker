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
      ev(d1, 100, 'stg_start', 'u1', {'stg': 1}),
      ev(d1, 200, 'stg_cmp', 'u1', {'stg': 1}),
      ev(d1, 300, 'stg_start', 'u2', {'stg': 2}),
    ]);
    store.replaceDay(d2, [ev(d2, 600, 'stg_start', 'u3', {'stg': 1})]);
    handler = buildHandler(store);
  });
  tearDown(() => store.close());

  Future<Response> send(String path, {String method = 'GET'}) async =>
      await handler(Request(method, Uri.parse('http://localhost$path')));

  Future<(int, Object?)> getJson(String path) async {
    final res = await send(path);
    return (res.statusCode, jsonDecode(await res.readAsString()));
  }

  test('GET /days', () async {
    final (status, body) = await getJson('/days');
    expect(status, 200);
    expect((body as List).map((e) => e['day']), [d1, d2]);
  });

  test('GET /events/names', () async {
    final (status, body) = await getJson('/events/names');
    expect(status, 200);
    expect(body, ['stg_cmp', 'stg_start']);
  });

  test('GET /events/count with name filter', () async {
    final (status, body) = await getJson('/events/count?from=$d1&to=$d2&name=stg_start');
    expect(status, 200);
    expect(body, [
      {'day': d1, 'eventName': 'stg_start', 'count': 2},
      {'day': d2, 'eventName': 'stg_start', 'count': 1},
    ]);
  });

  test('GET /events/param', () async {
    final (status, body) = await getJson('/events/param?name=stg_start&key=stg&from=$d1&to=$d2');
    expect(status, 200);
    expect(body, [
      {'value': '1', 'count': 2},
      {'value': '2', 'count': 1},
    ]);
  });

  test('GET /funnel', () async {
    final (status, body) = await getJson('/funnel?steps=stg_start,stg_cmp&from=$d1&to=$d2');
    expect(status, 200);
    expect(body, [
      {'eventName': 'stg_start', 'users': 3},
      {'eventName': 'stg_cmp', 'users': 1},
    ]);
  });

  group('bad requests return 400 JSON', () {
    for (final path in [
      '/events/count?to=$d2',
      '/events/count?from=bad&to=$d2',
      '/events/count?from=2026-02-30&to=$d2',
      '/events/count?from=$d2&to=$d1',
      '/events/param?name=stg_start&from=$d1&to=$d2',
      '/events/param?name=stg_start&key=stg%3BDROP&from=$d1&to=$d2',
      '/events/param?key=stg&from=$d1&to=$d2',
      '/funnel?steps=%20,%20&from=$d1&to=$d2',
      '/funnel?from=$d1&to=$d2',
      '/funnel?steps=a,b,c,d,e,f,g,h,i,j,k&from=$d1&to=$d2',
    ]) {
      test(path, () async {
        final (status, body) = await getJson(path);
        expect(status, 400);
        expect((body as Map)['error'], isA<String>());
      });
    }
  });

  test('CORS header on responses and OPTIONS preflight', () async {
    final res = await send('/days');
    expect(res.headers['access-control-allow-origin'], '*');
    final pre = await send('/events/count', method: 'OPTIONS');
    expect(pre.statusCode, 200);
    expect(pre.headers['access-control-allow-methods'], contains('GET'));
  });

  test('unknown route is 404', () async {
    expect((await send('/nope')).statusCode, 404);
  });
}
