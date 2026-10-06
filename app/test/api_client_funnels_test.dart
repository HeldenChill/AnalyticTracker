import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const def = FunnelDef(name: 'F', windowMinutes: 60, steps: [FunnelStepDef(event: 'a')]);
const saved = {
  'id': 7, 'name': 'F', 'windowMinutes': 60,
  'steps': [{'event': 'a', 'paramKey': null, 'paramValue': null}],
  'updatedAt': '2026-10-06T00:00:00.000Z',
};

void main() {
  test('create posts JSON and accepts 201', () async {
    final mock = MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/funnels');
      expect(req.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(req.body), def.toJson());
      return http.Response(jsonEncode(saved), 201);
    });
    final s = await ApiClient('http://h:8080', client: mock).createFunnel(def);
    expect(s.id, 7);
  });

  test('update puts to /funnels/<id>; delete accepts 204', () async {
    final seen = <String>[];
    final mock = MockClient((req) async {
      seen.add('${req.method} ${req.url.path}');
      return req.method == 'DELETE' ? http.Response('', 204) : http.Response(jsonEncode(saved), 200);
    });
    final c = ApiClient('http://h:8080', client: mock);
    await c.updateFunnel(7, def);
    await c.deleteFunnel(7);
    expect(seen, ['PUT /funnels/7', 'DELETE /funnels/7']);
  });

  test('run sends def and filters', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/funnels/run');
      expect(jsonDecode(req.body), {'def': def.toJson(), 'from': '2026-10-01', 'to': '2026-10-02', 'platform': 'IOS'});
      return http.Response(jsonEncode({'steps': [], 'totalConversion': null, 'biggestDropIndex': null}), 200);
    });
    final r = await ApiClient('http://h:8080', client: mock)
        .runFunnel(def, const Filters(from: '2026-10-01', to: '2026-10-02', platform: 'IOS'));
    expect(r.steps, isEmpty);
  });

  test('list funnels and param keys', () async {
    final mock = MockClient((req) async {
      if (req.url.path == '/funnels') return http.Response(jsonEncode([saved]), 200);
      expect(req.url.queryParameters, {'name': 'tut', 'from': '2026-10-01', 'to': '2026-10-02'});
      return http.Response(jsonEncode(['step']), 200);
    });
    final c = ApiClient('http://h:8080', client: mock);
    expect((await c.funnels()).single.name, 'F');
    expect(await c.paramKeys('tut', const Filters(from: '2026-10-01', to: '2026-10-02')), ['step']);
  });

  test('400 on save surfaces the server message', () async {
    final mock = MockClient((_) async => http.Response(jsonEncode({'error': 'Add at least one step'}), 400));
    expect(
      ApiClient('http://h:8080', client: mock).createFunnel(def),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Add at least one step')),
    );
  });
}
