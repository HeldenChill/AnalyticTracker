import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';

const onboarding = {
  'name': 'Onboarding',
  'windowMinutes': 1440,
  'steps': [
    {'event': 'first_open'},
    {'event': 'tut', 'paramKey': 'step', 'paramValue': '1'},
  ],
};

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    store.replaceDay(d1, [
      evx(d1, 1, 'first_open', 'u1'),
      evx(d1, 2, 'tut', 'u1', params: {'step': 1}),
      evx(d1, 3, 'first_open', 'u2', platform: 'IOS'),
    ]);
    handler = buildHandler(store);
  });
  tearDown(() => store.close());

  Future<(int, Object?)> call(String method, String path, [Object? body]) async {
    final res = await handler(Request(method, Uri.parse('http://localhost$path'),
        body: body == null ? null : (body is String ? body : jsonEncode(body))));
    final text = await res.readAsString();
    return (res.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  test('CRUD round trip', () async {
    final (c1, created) = await call('POST', '/funnels', onboarding);
    expect(c1, 201);
    final id = (created as Map)['id'] as int;
    expect(created['name'], 'Onboarding');
    // Legacy paramKey/paramValue body is stored in the BUG-0008 `params` shape.
    expect((created['steps'] as List)[1], {
      'event': 'tut',
      'params': [
        {'key': 'step', 'value': '1'},
      ],
    });

    final (c2, list) = await call('GET', '/funnels');
    expect(c2, 200);
    expect((list as List).single['id'], id);

    final (c3, updated) = await call('PUT', '/funnels/$id', {...onboarding, 'name': 'Renamed'});
    expect(c3, 200);
    expect((updated as Map)['name'], 'Renamed');

    final (c4, _) = await call('DELETE', '/funnels/$id');
    expect(c4, 204);
    final (c5, gone) = await call('DELETE', '/funnels/$id');
    expect(c5, 404);
    expect((gone as Map)['error'], isA<String>());
  });

  test('PUT unknown or non-numeric id is 404', () async {
    expect((await call('PUT', '/funnels/999', onboarding)).$1, 404);
    expect((await call('PUT', '/funnels/abc', onboarding)).$1, 404);
  });

  group('bad bodies', () {
    final cases = <String, Object>{
      'not json': 'not json',
      'json array': [1, 2],
      'missing steps': {'name': 'x', 'windowMinutes': 60},
      'steps wrong type': {'name': 'x', 'windowMinutes': 60, 'steps': 'a,b'},
      'no steps': {'name': 'x', 'windowMinutes': 60, 'steps': []},
      'blank name': {...onboarding, 'name': ' '},
    };
    cases.forEach((label, body) {
      test(label, () async {
        final (status, res) = await call('POST', '/funnels', body);
        expect(status, 400);
        expect((res as Map)['error'], isA<String>());
      });
    });

    test('validation message is passed through', () async {
      final (_, res) = await call('POST', '/funnels', {'name': 'x', 'windowMinutes': 60, 'steps': []});
      expect((res as Map)['error'], 'Add at least one step');
    });
  });

  test('POST /funnels/run applies filters', () async {
    final (status, res) = await call('POST', '/funnels/run', {'def': onboarding, 'from': d1, 'to': d1});
    expect(status, 200);
    final steps = (res as Map)['steps'] as List;
    expect(steps.map((s) => s['players']), [2, 1]);
    expect(res['totalConversion'], 0.5);
    expect(res['biggestDropIndex'], 1);

    final (_, ios) = await call('POST', '/funnels/run', {'def': onboarding, 'from': d1, 'to': d1, 'platform': 'IOS'});
    expect(((ios as Map)['steps'] as List).map((s) => s['players']), [1, 0]);
  });

  test('test-device events need test=1 (BUG-0007)', () async {
    store.replaceDay('2026-10-02', [evx('2026-10-02', 1, 'first_open', 'dev', params: {'debug_event': 1})]);
    const d2 = '2026-10-02';
    final (_, off) = await call('POST', '/funnels/run', {'def': onboarding, 'from': d2, 'to': d2});
    expect(((off as Map)['steps'] as List).first['players'], 0);
    final (_, on) = await call('POST', '/funnels/run', {'def': onboarding, 'from': d2, 'to': d2, 'test': '1'});
    expect(((on as Map)['steps'] as List).first['players'], 1);
    final (_, ov) = await call('GET', '/overview?from=$d2&to=$d2');
    expect((ov as Map)['kpis']['newUsers'], 0);
    final (_, ovTest) = await call('GET', '/overview?from=$d2&to=$d2&test=1');
    expect((ovTest as Map)['kpis']['newUsers'], 1);
  });

  test('POST /funnels/run rejects bad range and bad def', () async {
    expect((await call('POST', '/funnels/run', {'def': onboarding, 'from': d1})).$1, 400);
    expect((await call('POST', '/funnels/run', {'def': onboarding, 'from': '2026-10-02', 'to': d1})).$1, 400);
    expect((await call('POST', '/funnels/run', {'from': d1, 'to': d1})).$1, 400);
  });

  test('GET /events/param-keys', () async {
    final (status, body) = await call('GET', '/events/param-keys?name=tut&from=$d1&to=$d1');
    expect(status, 200);
    expect(body, ['step']);
    expect((await call('GET', '/events/param-keys?from=$d1&to=$d1')).$1, 400);
  });

  test('CORS preflight lists write methods', () async {
    final res = await handler(Request('OPTIONS', Uri.parse('http://localhost/funnels')));
    final methods = res.headers['access-control-allow-methods']!;
    for (final m in ['GET', 'POST', 'PUT', 'DELETE']) {
      expect(methods, contains(m));
    }
  });
}
