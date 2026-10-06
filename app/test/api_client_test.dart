import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonRes(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  test('days hits /days and parses', () async {
    final mock = MockClient((req) async {
      expect(req.url.toString(), 'http://host:8080/days');
      return jsonRes([
        {'day': '2026-10-01', 'rowCount': 3, 'pulledAt': 'x'}
      ]);
    });
    final days = await ApiClient('http://host:8080', client: mock).days();
    expect(days.single.rowCount, 3);
  });

  test('trailing slash in base url is fine', () async {
    final mock = MockClient((req) async {
      expect(req.url.toString(), 'http://host:8080/events/names');
      return jsonRes(['a']);
    });
    expect(await ApiClient('http://host:8080/', client: mock).eventNames(), ['a']);
  });

  test('counts sends query params, omits null name', () async {
    final seen = <Map<String, String>>[];
    final mock = MockClient((req) async {
      expect(req.url.path, '/events/count');
      seen.add(req.url.queryParameters);
      return jsonRes([
        {'day': '2026-10-01', 'eventName': 'stg_start', 'count': 4}
      ]);
    });
    final c = ApiClient('http://host:8080', client: mock);
    final r = await c.counts('2026-10-01', '2026-10-02', name: 'stg_start');
    await c.counts('2026-10-01', '2026-10-02');
    expect(r.single.count, 4);
    expect(seen, [
      {'from': '2026-10-01', 'to': '2026-10-02', 'name': 'stg_start'},
      {'from': '2026-10-01', 'to': '2026-10-02'},
    ]);
  });

  test('param and funnel parse', () async {
    final mock = MockClient((req) async {
      if (req.url.path == '/events/param') {
        expect(req.url.queryParameters['key'], 'stg');
        return jsonRes([
          {'value': '1', 'count': 2}
        ]);
      }
      expect(req.url.queryParameters['steps'], 'a,b');
      return jsonRes([
        {'eventName': 'a', 'users': 5},
        {'eventName': 'b', 'users': 2}
      ]);
    });
    final c = ApiClient('http://host:8080', client: mock);
    expect((await c.param('stg_start', 'stg', '2026-10-01', '2026-10-02')).single.value, '1');
    expect((await c.funnel('a,b', '2026-10-01', '2026-10-02')).map((f) => f.users), [5, 2]);
  });

  test('400 surfaces server error message', () async {
    final mock = MockClient((_) async => jsonRes({'error': '"from" must be a date YYYY-MM-DD'}, 400));
    expect(
      ApiClient('http://host:8080', client: mock).counts('x', 'y'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', '"from" must be a date YYYY-MM-DD')),
    );
  });

  test('non-JSON error body falls back to HTTP status', () async {
    final mock = MockClient((_) async => http.Response('Route not found', 404));
    expect(
      ApiClient('http://host:8080', client: mock).days(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'HTTP 404')),
    );
  });

  test('network failure becomes readable ApiException', () async {
    final mock = MockClient((_) async => throw http.ClientException('Connection refused'));
    expect(
      ApiClient('http://host:8080', client: mock).days(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Cannot reach server'))),
    );
  });
}
