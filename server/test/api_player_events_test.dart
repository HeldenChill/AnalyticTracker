import 'dart:convert';
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

  test('GET /players/:uid/events returns events ascending', () async {
    store.replaceDay('2026-10-01', [
      RawEvent(day: '2026-10-01', tsMicros: 1000, eventName: 'e1', userPseudoId: 'p1', paramsJson: jsonEncode({'x': 1}), userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
      RawEvent(day: '2026-10-01', tsMicros: 2000, eventName: 'e2', userPseudoId: 'p1', paramsJson: jsonEncode({'y': 2}), userPropsJson: '{}', platform: 'ANDROID', appVersion: '1.0'),
    ]);

    final res = await client.get(baseUri.replace(
      path: '/players/p1/events',
      queryParameters: {'fromTs': '500', 'toTs': '2500'},
    ));
    expect(res.statusCode, equals(200));
    final list = jsonDecode(res.body) as List;
    expect(list, hasLength(2));
    expect(list[0]['event'], equals('e1'));
    expect(list[1]['event'], equals('e2'));
  });

  test('unknown player uid returns empty list with 200', () async {
    final res = await client.get(baseUri.replace(
      path: '/players/nobody/events',
      queryParameters: {'fromTs': '0', 'toTs': '1000'},
    ));
    expect(res.statusCode, equals(200));
    expect(jsonDecode(res.body), equals([]));
  });

  test('validates fromTs and toTs query params', () async {
    final missing = await client.get(baseUri.replace(path: '/players/p1/events'));
    expect(missing.statusCode, equals(400));

    final invalid = await client.get(baseUri.replace(
      path: '/players/p1/events',
      queryParameters: {'fromTs': 'abc', 'toTs': '100'},
    ));
    expect(invalid.statusCode, equals(400));
  });
}
