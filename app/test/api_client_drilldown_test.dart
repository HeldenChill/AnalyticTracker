import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient drill-down', () {
    test('funnelPlayers posts request body and parses result', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, equals('/funnels/players'));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['step'], equals(2));
        expect(body['outcome'], equals('converted'));
        return http.Response(
          jsonEncode({
            'total': 1,
            'players': [
              {'uid': 'p1', 'entryTs': 100, 'reached': 2, 'lastTs': 200, 'stepTs': [100, 200]}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient('http://localhost', client: mock);
      const def = FunnelDef(
        name: 'F',
        windowMinutes: 1440,
        steps: [FunnelStepDef(event: 'a'), FunnelStepDef(event: 'b')],
      );
      const f = Filters(from: '2026-10-01', to: '2026-10-01');

      final res = await client.funnelPlayers(def, f, step: 2, outcome: FunnelPlayerOutcome.converted);
      expect(res.total, equals(1));
      expect(res.players.first.uid, equals('p1'));
    });

    test('playerEvents gets player events and parses result', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, equals('/players/p1/events'));
        expect(req.url.queryParameters['fromTs'], equals('100'));
        expect(req.url.queryParameters['toTs'], equals('200'));
        return http.Response(
          jsonEncode([
            {'ts': 100, 'event': 'ev1', 'params': {'k': 'v'}}
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient('http://localhost', client: mock);
      final events = await client.playerEvents('p1', fromTs: 100, toTs: 200);
      expect(events, hasLength(1));
      expect(events.first.event, equals('ev1'));
    });
  });
}
