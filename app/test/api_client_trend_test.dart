import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('ApiClient.runFunnel sends interval in request body', () async {
    late Map<String, dynamic> capturedBody;
    final mock = MockClient((req) async {
      if (req.url.path == '/funnels/run') {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(const FunnelResult(
            steps: [],
            totalConversion: null,
            biggestDropIndex: null,
            trend: [
              FunnelTrendPoint(start: '2026-10-01', players: [], totalConversion: null, incomplete: false),
            ],
          ).toJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    final client = ApiClient('http://localhost', client: mock);
    final def = const FunnelDef(name: 'F', windowMinutes: 1440, steps: []);
    final f = const Filters(from: '2026-10-01', to: '2026-10-02');

    final res = await client.runFunnel(def, f, interval: FunnelInterval.week);
    expect(capturedBody['interval'], 'week');
    expect(res.trend.length, 1);
    expect(res.trend.first.start, '2026-10-01');
  });
}
