import 'dart:convert';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:analytic_server/src/api.dart';
import 'package:analytic_server/src/event_store.dart';
import 'package:analytic_server/src/raw_event.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';

void main() {
  late EventStore store;
  late http.Client client;
  late Uri baseUri;
  dynamic server;

  setUp(() async {
    store = EventStore.inMemory();
    server = await io.serve(buildHandler(store), '127.0.0.1', 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    client = http.Client();
  });

  tearDown(() async {
    client.close();
    await server.close();
    store.close();
  });

  final def = FunnelDef(
    name: 'Tutorial',
    windowMinutes: 1440,
    steps: const [
      FunnelStepDef(event: 'start'),
      FunnelStepDef(event: 'finish'),
    ],
  );

  test('POST /funnels/players returns players list and total', () async {
    store.replaceDay('2026-10-01', [
      RawEvent(day: '2026-10-01', tsMicros: 100, eventName: 'start', userPseudoId: 'p1', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
      RawEvent(day: '2026-10-01', tsMicros: 200, eventName: 'finish', userPseudoId: 'p1', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
      RawEvent(day: '2026-10-01', tsMicros: 150, eventName: 'start', userPseudoId: 'p2', paramsJson: '{}', userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
    ]);

    final res = await client.post(
      baseUri.replace(path: '/funnels/players'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'def': def.toJson(),
        'from': '2026-10-01',
        'to': '2026-10-01',
        'step': 2,
        'outcome': 'converted',
      }),
    );
    expect(res.statusCode, equals(200));
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    expect(j['total'], equals(1));
    expect((j['players'] as List).first['uid'], equals('p1'));
  });

  test('POST /funnels/players validates step, outcome, and limit', () async {
    final badStep = await client.post(
      baseUri.replace(path: '/funnels/players'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'def': def.toJson(),
        'from': '2026-10-01',
        'to': '2026-10-01',
        'step': 1, // must be >= 2
        'outcome': 'converted',
      }),
    );
    expect(badStep.statusCode, equals(400));

    final badOutcome = await client.post(
      baseUri.replace(path: '/funnels/players'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'def': def.toJson(),
        'from': '2026-10-01',
        'to': '2026-10-01',
        'step': 2,
        'outcome': 'unknown',
      }),
    );
    expect(badOutcome.statusCode, equals(400));

    final badLimit = await client.post(
      baseUri.replace(path: '/funnels/players'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'def': def.toJson(),
        'from': '2026-10-01',
        'to': '2026-10-01',
        'step': 2,
        'outcome': 'converted',
        'limit': 999, // max 500
      }),
    );
    expect(badLimit.statusCode, equals(400));
  });
}
