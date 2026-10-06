import 'dart:convert';

import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonRes(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

void main() {
  const f = Filters(from: '2026-10-01', to: '2026-10-02', platform: 'IOS');

  test('overview sends filters and parses', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/overview');
      expect(req.url.queryParameters, {'from': '2026-10-01', 'to': '2026-10-02', 'platform': 'IOS'});
      return jsonRes({
        'kpis': {'dau': 1, 'newUsers': 1, 'sessions': 0, 'sessionsPerDau': null, 'playtimeMinPerDau': null, 'uninstalls': 0},
        'previous': null,
        'daily': [
          {'day': '2026-10-01', 'dau': 1, 'newUsers': 1, 'sessions': 0, 'uninstalls': 0}
        ],
      });
    });
    final o = await ApiClient('http://h:8080', client: mock).overview(f);
    expect(o.kpis.dau, 1.0);
    expect(o.previous, isNull);
    expect(o.daily.single.newUsers, 1);
  });

  test('filterOptions, retention, progression parse', () async {
    final mock = MockClient((req) async {
      switch (req.url.path) {
        case '/filters':
          return jsonRes({'platforms': ['ANDROID'], 'versions': ['1.0.0']});
        case '/retention':
          return jsonRes({
            'offsets': [1],
            'lastDataDay': '2026-10-02',
            'cohorts': [
              {'day': '2026-10-01', 'size': 2, 'retained': [1]}
            ],
            'average': [0.5],
          });
        default:
          return jsonRes({'stages': []});
      }
    });
    final c = ApiClient('http://h:8080', client: mock);
    expect((await c.filterOptions()).platforms, ['ANDROID']);
    expect((await c.retention(f)).average, [0.5]);
    expect((await c.progression(f)).stages, isEmpty);
  });

  test('v1 counts forwards platform and version', () async {
    final mock = MockClient((req) async {
      expect(req.url.queryParameters,
          {'from': '2026-10-01', 'to': '2026-10-02', 'platform': 'IOS', 'version': '1.0'});
      return jsonRes([]);
    });
    await ApiClient('http://h:8080', client: mock)
        .counts('2026-10-01', '2026-10-02', platform: 'IOS', version: '1.0');
  });
}
