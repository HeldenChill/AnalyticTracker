import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const d1 = '2026-10-01';

const richer = {
  'name': 'Richer',
  'windowMinutes': null,
  'order': 'any',
  'steps': [
    {'event': 'first_open', 'params': []},
    {
      'event': 'level_start',
      'params': [
        {'key': 'lvl', 'op': 'gte', 'value': '5'},
      ],
      'or': [
        {'event': 'level_skip', 'params': []},
      ],
    },
  ],
};

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    store.replaceDay(d1, [
      evx(d1, 1, 'first_open', 'u1'), evx(d1, 2, 'level_start', 'u1', params: {'lvl': 7}),
      evx(d1, 1, 'first_open', 'u2'), evx(d1, 2, 'level_skip', 'u2'),
      evx(d1, 1, 'first_open', 'u3'), evx(d1, 2, 'level_start', 'u3', params: {'lvl': 2}),
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

  test('save and list keep order, operators and or-events', () async {
    final (status, created) = await call('POST', '/funnels', richer);
    expect(status, 201);
    expect((created as Map)['order'], 'any');
    expect((created['steps'] as List)[1], (richer['steps'] as List)[1]);
    final (_, list) = await call('GET', '/funnels');
    expect((list as List).single['order'], 'any');
  });

  test('run: lvl >= 5 or level_skip', () async {
    final (status, res) = await call('POST', '/funnels/run', {'def': richer, 'from': d1, 'to': d1});
    expect(status, 200);
    // u1 lvl 7 matches, u2 skipped (or-event), u3 lvl 2 does not.
    expect([for (final s in (res as Map)['steps'] as List) s['players']], [3, 2]);
    expect((res['steps'] as List)[1]['or'], [
      {'event': 'level_skip', 'params': <Object>[]},
    ]);
  });

  group('bad bodies are 400', () {
    final cases = <String, (Object, String)>{
      'unknown operator': (
        {
          'name': 'x',
          'windowMinutes': 60,
          'steps': [
            {
              'event': 'a',
              'params': [
                {'key': 'k', 'op': '>=', 'value': '1'},
              ],
            },
          ],
        },
        'Malformed funnel definition',
      ),
      'unknown order': (
        {
          'name': 'x',
          'windowMinutes': 60,
          'order': 'loose',
          'steps': [
            {'event': 'a'},
          ],
        },
        'Malformed funnel definition',
      ),
      'number operator with text': (
        {
          'name': 'x',
          'windowMinutes': 60,
          'steps': [
            {
              'event': 'a',
              'params': [
                {'key': 'lvl', 'op': 'gt', 'value': 'abc'},
              ],
            },
          ],
        },
        'Step 1: "lvl greater than" needs a number',
      ),
      'exclusion in any order': (
        {
          'name': 'x',
          'windowMinutes': 60,
          'order': 'any',
          'steps': [
            {'event': 'a'},
            {
              'event': 'b',
              'exclude': [
                {'event': 'c'},
              ],
            },
          ],
        },
        'Exclusions need strict order',
      ),
    };
    cases.forEach((label, c) {
      test(label, () async {
        final (status, res) = await call('POST', '/funnels', c.$1);
        expect(status, 400);
        expect((res as Map)['error'], c.$2);
      });
    });
  });
}
