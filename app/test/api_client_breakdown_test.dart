import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiClient.runFunnel passes breakdown in body', () async {
    late Map<String, dynamic> seenBody;
    final client = ApiClient(
      'http://example.com',
      client: MockClient((req) async {
        if (req.url.path == '/funnels/run') {
          seenBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'steps': [],
              'totalConversion': null,
              'biggestDropIndex': null,
              'segments': [],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    const def = FunnelDef(name: 'F', windowMinutes: 1440, steps: [FunnelStepDef(event: 'e1')]);
    const f = Filters(from: '2026-10-01', to: '2026-10-02');
    const b = FunnelBreakdown(by: FunnelBreakdownBy.platform);

    await client.runFunnel(def, f, breakdown: b);
    expect(seenBody['breakdown'], {'by': 'platform'});
  });

  test('ApiClient.userPropKeys calls /events/user-prop-keys', () async {
    late Uri seenUri;
    final client = ApiClient(
      'http://example.com',
      client: MockClient((req) async {
        seenUri = req.url;
        return http.Response(jsonEncode(['first_open_time', 'vip']), 200);
      }),
    );

    final keys = await client.userPropKeys('2026-10-01', '2026-10-02');
    expect(seenUri.path, '/events/user-prop-keys');
    expect(keys, ['first_open_time', 'vip']);
  });
}
