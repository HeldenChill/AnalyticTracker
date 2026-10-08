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
  });

  tearDown(() => store.close());

  Future<Response> postRun(Map<String, dynamic> body) async => await handler(
        Request('POST', Uri.parse('http://localhost/funnels/run'),
            headers: {'content-type': 'application/json'}, body: jsonEncode(body)),
      );

  final validDef = const FunnelDef(
    name: 'F1',
    windowMinutes: 1440,
    steps: [FunnelStepDef(event: 'e1'), FunnelStepDef(event: 'e2')],
  ).toJson();

  test('POST /funnels/run accepts interval day and week', () async {
    final resDay = await postRun({
      'def': validDef,
      'from': '2026-10-01',
      'to': '2026-10-02',
      'interval': 'day',
    });
    expect(resDay.statusCode, 200);
    final jDay = jsonDecode(await resDay.readAsString()) as Map;
    expect(jDay['trend'], isList);
    expect((jDay['trend'] as List).length, 2);

    final resWeek = await postRun({
      'def': validDef,
      'from': '2026-10-01',
      'to': '2026-10-02',
      'interval': 'week',
    });
    expect(resWeek.statusCode, 200);
    final jWeek = jsonDecode(await resWeek.readAsString()) as Map;
    expect(jWeek['trend'], isList);
  });

  test('POST /funnels/run rejects invalid interval with 400', () async {
    final res = await postRun({
      'def': validDef,
      'from': '2026-10-01',
      'to': '2026-10-02',
      'interval': 'hourly',
    });
    expect(res.statusCode, 400);
    final j = jsonDecode(await res.readAsString()) as Map;
    expect(j['error'], contains('Unknown interval "hourly"'));
  });
}
