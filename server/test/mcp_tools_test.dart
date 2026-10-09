import 'dart:convert';
import 'dart:io';

import 'package:analytic_server/analytic_server.dart';
import 'package:dart_mcp/server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const base = 'http://h:8080';
const range = {'from': '2026-10-01', 'to': '2026-10-07'};

const savedList = [
  {
    'id': 7,
    'name': 'Onboarding',
    'windowMinutes': 1440,
    'steps': [
      {'event': 'first_open', 'params': <Object>[]},
    ],
    'updatedAt': '2026-10-06T00:00:00.000Z',
  },
];

String textOf(CallToolResult r) => (r.content.single as TextContent).text;

void main() {
  late List<http.Request> seen;
  late AnalyticTools tools;

  /// Every request is recorded; [reply] decides the response (default 200 `{}`).
  void serve([http.Response Function(http.Request req)? reply]) {
    seen = [];
    tools = AnalyticTools(base, MockClient((req) async {
      seen.add(req);
      return reply == null ? http.Response('{}', 200) : reply(req);
    }));
  }

  setUp(serve);

  test('all 18 tools, spec order, with annotations', () {
    expect(tools.all.keys, [
      'data_health', 'filter_options', 'list_events', 'overview', 'retention', 'progression',
      'event_counts', 'param_keys', 'param_values', 'user_prop_keys', 'list_funnels', 'run_funnel',
      'funnel_players', 'player_events', 'save_funnel', 'delete_funnel', 'import_export',
      'analysis_clusters',
    ]);
    bool? readOnly(String n) => tools.all[n]!.$1.toolAnnotations?.readOnlyHint;
    bool? destructive(String n) => tools.all[n]!.$1.toolAnnotations?.destructiveHint;
    for (final n in [
      'data_health', 'overview', 'run_funnel', 'list_funnels', 'param_values', 'user_prop_keys',
      'funnel_players', 'player_events', 'analysis_clusters',
    ]) {
      expect(readOnly(n), isTrue, reason: n);
    }
    expect(readOnly('save_funnel'), isFalse);
    expect(destructive('save_funnel'), isFalse);
    expect(destructive('delete_funnel'), isTrue);
    expect(destructive('import_export'), isTrue);
    expect(tools.all['overview']!.$1.inputSchema.required, ['from', 'to']);
    expect(tools.all['param_values']!.$1.inputSchema.required, ['from', 'to', 'event', 'key']);
    expect(tools.all['user_prop_keys']!.$1.inputSchema.required, ['from', 'to']);
    expect(tools.all['analysis_clusters']!.$1.inputSchema.required, ['from', 'to']);
  });

  test('analysis_clusters sends filters and optional k', () async {
    await tools.call('analysis_clusters', {...range, 'include_test': true});
    await tools.call('analysis_clusters', {...range, 'k': 3});
    expect(seen[0].url.path, '/analysis/clusters');
    expect(seen[0].url.queryParameters, {...range, 'test': '1'});
    expect(seen[1].url.queryParameters, {...range, 'k': '3'});
  });

  group('filters', () {
    test('only from/to by default; include_test true -> test=1', () async {
      await tools.call('overview', range);
      expect(seen.single.method, 'GET');
      expect(seen.single.url.path, '/overview');
      expect(seen.single.url.queryParameters, range);

      serve();
      await tools.call('retention', {...range, 'platform': 'IOS', 'version': '1.0.3', 'include_test': true});
      expect(seen.single.url.path, '/retention');
      expect(seen.single.url.queryParameters,
          {...range, 'platform': 'IOS', 'version': '1.0.3', 'test': '1'});
    });

    test('include_test false sends no test param', () async {
      await tools.call('progression', {...range, 'include_test': false});
      expect(seen.single.url.path, '/progression');
      expect(seen.single.url.queryParameters, range);
    });

    test('explore tools map event/key/name', () async {
      await tools.call('event_counts', {...range, 'name': 'tut'});
      await tools.call('param_keys', {...range, 'event': 'tut'});
      await tools.call('param_values', {...range, 'event': 'tut', 'key': 'step'});
      await tools.call('user_prop_keys', range);
      expect([for (final r in seen) r.url.path], ['/events/count', '/events/param-keys', '/events/param', '/events/user-prop-keys']);
      expect(seen[0].url.queryParameters, {...range, 'name': 'tut'});
      expect(seen[1].url.queryParameters, {...range, 'name': 'tut'});
      expect(seen[2].url.queryParameters, {...range, 'name': 'tut', 'key': 'step'});
      expect(seen[3].url.queryParameters, range);
    });
  });

  test('response body is returned unchanged as text', () async {
    serve((_) => http.Response('{"kpis":{"dau":3.5}}', 200));
    final r = await tools.call('overview', range);
    expect(r.isError, isNot(true));
    expect(textOf(r), '{"kpis":{"dau":3.5}}');
  });

  test('data_health adds missingDays between first and last stored day', () async {
    serve((_) => http.Response(
        jsonEncode([
          {'day': '2026-10-01', 'rowCount': 5, 'pulledAt': 'x'},
          {'day': '2026-10-04', 'rowCount': 2, 'pulledAt': 'y'},
        ]),
        200));
    final j = jsonDecode(textOf(await tools.call('data_health', {}))) as Map;
    expect(seen.single.url.path, '/days');
    expect((j['days'] as List).length, 2);
    expect(j['missingDays'], ['2026-10-02', '2026-10-03']);
  });

  group('run_funnel', () {
    test('inline def posts def + filters', () async {
      const def = {'name': 'x', 'windowMinutes': null, 'steps': [{'event': 'a', 'params': []}]};
      await tools.call('run_funnel', {...range, 'def': def, 'include_test': true});
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/funnels/run');
      expect(jsonDecode(seen.single.body), {'def': def, ...range, 'test': '1'});
    });

    test('breakdown parameters pass breakdown object', () async {
      const def = {'name': 'x', 'windowMinutes': null, 'steps': [{'event': 'a', 'params': []}]};
      await tools.call('run_funnel', {
        ...range,
        'def': def,
        'breakdown_by': 'param',
        'breakdown_key': 'vip',
      });
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/funnels/run');
      expect(jsonDecode(seen.single.body), {
        'def': def,
        ...range,
        'breakdown': {'by': 'param', 'key': 'vip'},
      });
    });

    test('interval parameter passes interval string', () async {
      const def = {'name': 'x', 'windowMinutes': null, 'steps': [{'event': 'a', 'params': []}]};
      await tools.call('run_funnel', {
        ...range,
        'def': def,
        'interval': 'day',
      });
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/funnels/run');
      expect(jsonDecode(seen.single.body), {
        'def': def,
        ...range,
        'interval': 'day',
      });
    });

    test('saved id fetches /funnels then runs its def', () async {
      serve((req) => req.url.path == '/funnels' ? http.Response(jsonEncode(savedList), 200) : http.Response('{}', 200));
      await tools.call('run_funnel', {...range, 'id': 7});
      expect([for (final r in seen) '${r.method} ${r.url.path}'], ['GET /funnels', 'POST /funnels/run']);
      expect(jsonDecode(seen[1].body), {
        'def': {'name': 'Onboarding', 'windowMinutes': 1440, 'steps': savedList[0]['steps']},
        ...range,
      });
    });

    test('saved any-order funnel keeps its order when run', () async {
      final saved = [
        {...savedList[0], 'order': 'any'},
      ];
      serve((req) => req.url.path == '/funnels' ? http.Response(jsonEncode(saved), 200) : http.Response('{}', 200));
      await tools.call('run_funnel', {...range, 'id': 7});
      expect((jsonDecode(seen[1].body) as Map)['def']['order'], 'any');
    });

    test('unknown saved id is an error, no run request', () async {
      serve((req) => http.Response(jsonEncode(savedList), 200));
      final r = await tools.call('run_funnel', {...range, 'id': 99});
      expect(r.isError, isTrue);
      expect(textOf(r), 'Funnel 99 not found');
      expect(seen.length, 1);
    });

    test('both or neither of id/def is an error before any HTTP call', () async {
      for (final args in [
        {...range},
        {...range, 'id': 7, 'def': {'name': 'x'}},
      ]) {
        final r = await tools.call('run_funnel', args);
        expect(r.isError, isTrue);
        expect(textOf(r), 'Pass exactly one of "id" (saved funnel) or "def" (inline definition)');
      }
      expect(seen, isEmpty);
    });
  });

  test('save_funnel posts without id, puts with id; delete_funnel', () async {
    const def = {'name': 'x', 'windowMinutes': 60, 'steps': [{'event': 'a', 'params': []}]};
    await tools.call('save_funnel', {'def': def});
    await tools.call('save_funnel', {'def': def, 'id': 7});
    serve((_) => http.Response('', 204));
    final del = await tools.call('delete_funnel', {'id': 7});
    expect(textOf(del), '{"deleted":7}');
    expect('${seen.single.method} ${seen.single.url.path}', 'DELETE /funnels/7');
  });

  test('save_funnel sends the def as the JSON body', () async {
    const def = {'name': 'x', 'windowMinutes': 60, 'steps': [{'event': 'a', 'params': []}]};
    await tools.call('save_funnel', {'def': def, 'id': 3});
    expect('${seen.single.method} ${seen.single.url.path}', 'PUT /funnels/3');
    expect(seen.single.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(seen.single.body), def);
  });

  group('errors', () {
    test('API 400/404 surfaces the server message', () async {
      serve((_) => http.Response(jsonEncode({'error': 'Funnel 7 not found'}), 404));
      final r = await tools.call('delete_funnel', {'id': 7});
      expect(r.isError, isTrue);
      expect(textOf(r), 'Funnel 7 not found');
    });

    test('non-JSON error body falls back to HTTP status', () async {
      serve((_) => http.Response('boom', 500));
      final r = await tools.call('overview', range);
      expect(r.isError, isTrue);
      expect(textOf(r), 'HTTP 500');
    });

    test('server down gives the start-it hint', () async {
      tools = AnalyticTools(base, MockClient((_) async => throw http.ClientException('Connection refused')));
      final r = await tools.call('overview', range);
      expect(r.isError, isTrue);
      expect(textOf(r),
          startsWith('AnalyticTracker server not reachable at http://h:8080. Start it: cd server; dart run bin/server.dart'));
    });

    test('unknown tool name', () async {
      final r = await tools.call('nope', {});
      expect(r.isError, isTrue);
      expect(textOf(r), 'Unknown tool nope');
    });
  });

  group('import_export', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('mcp_import_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('dry run by default: sends file text with dryRun=1', () async {
      final f = File('${dir.path}/export.json')..writeAsStringSync('[{"day":"2026-10-01"}]');
      await tools.call('import_export', {'path': f.path});
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/import');
      expect(seen.single.url.queryParameters, {'dryRun': '1'});
      expect(seen.single.body, '[{"day":"2026-10-01"}]');
      expect(seen.single.headers['content-type'], startsWith('text/plain'));
    });

    test('dry_run false applies (no dryRun param)', () async {
      final f = File('${dir.path}/export.json')..writeAsStringSync('[]');
      await tools.call('import_export', {'path': f.path, 'dry_run': false});
      expect(seen.single.url.queryParameters, isEmpty);
    });

    test('missing file is an error, no HTTP call', () async {
      final r = await tools.call('import_export', {'path': '${dir.path}/nope.json'});
      expect(r.isError, isTrue);
      expect(textOf(r), startsWith('Cannot read ${dir.path}/nope.json'));
      expect(seen, isEmpty);
    });
  });
}
