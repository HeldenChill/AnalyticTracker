import 'dart:convert';
import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late EventStore store;
  late Handler handler;

  setUp(() {
    store = EventStore.inMemory();
    handler = buildHandler(store);

    store.replaceDay('2026-10-01', [
      const RawEvent(
        day: '2026-10-01',
        tsMicros: 1000,
        eventName: 'step1',
        userPseudoId: 'u1',
        paramsJson: '{"lvl": "1"}',
        userPropsJson: '{"vip": "A"}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
      const RawEvent(
        day: '2026-10-01',
        tsMicros: 2000,
        eventName: 'step2',
        userPseudoId: 'u1',
        paramsJson: '{}',
        userPropsJson: '{}',
        platform: 'ANDROID',
        appVersion: '1.0.0',
      ),
    ]);
  });

  Future<(int, dynamic)> call(String method, String path, {Object? body}) async {
    final req = Request(
      method,
      Uri.parse('http://localhost/$path'),
      body: body is String ? body : (body == null ? null : jsonEncode(body)),
      headers: body == null ? {} : {'content-type': 'application/json'},
    );
    final res = await handler(req);
    final text = await res.readAsString();
    return (res.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  test('POST /funnels/run validates breakdown key', () async {
    final def = const FunnelDef(
      name: 'Test',
      windowMinutes: 1440,
      steps: [FunnelStepDef(event: 'step1'), FunnelStepDef(event: 'step2')],
    ).toJson();

    // Bad operator / dimension
    final (st1, _) = await call('POST', 'funnels/run', body: {
      'def': def,
      'from': '2026-10-01',
      'to': '2026-10-01',
      'breakdown': {'by': 'unknown'},
    });
    expect(st1, 400);

    // Missing key for param breakdown
    final (st2, b2) = await call('POST', 'funnels/run', body: {
      'def': def,
      'from': '2026-10-01',
      'to': '2026-10-01',
      'breakdown': {'by': 'param'},
    });
    expect(st2, 400);
    expect(b2['error'], contains('requires a parameter key'));

    // Valid breakdown by platform returns segments
    final (st3, b3) = await call('POST', 'funnels/run', body: {
      'def': def,
      'from': '2026-10-01',
      'to': '2026-10-01',
      'breakdown': {'by': 'platform'},
    });
    expect(st3, 200);
    expect(b3['segments'], isNotEmpty);
    expect(b3['segments'][0]['value'], 'ANDROID');
  });
}
