import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';
import 'package:dart_mcp/client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test('MCP protocol: initialize, list 18 tools and the prompt, call one, schema validation', () async {
    final channel = StreamChannelController<String>();
    final api = MockClient((req) async => http.Response(jsonEncode({'path': req.url.path}), 200));
    AnalyticMcpServer(channel.local, AnalyticTools('http://h:8080', api));

    final client = MCPClient(Implementation(name: 'test-client', version: '0.0.1'));
    final server = client.connectServer(channel.foreign);
    addTearDown(client.shutdown);

    final init = await server.initialize(InitializeRequest(
      protocolVersion: ProtocolVersion.latestSupported,
      capabilities: client.capabilities,
      clientInfo: client.implementation,
    ));
    expect(init.serverInfo.name, 'analytic-tracker');
    expect(init.capabilities.tools, isNotNull);
    expect(init.capabilities.prompts, isNotNull);
    server.notifyInitialized();

    final list = await server.listTools(ListToolsRequest());
    expect(list.tools.length, 18);
    expect(list.tools.map((t) => t.name), containsAll(['import_export', 'analysis_clusters']));

    final prompts = await server.listPrompts(ListPromptsRequest());
    expect(prompts.prompts.map((p) => p.name), ['weekly_insights']);
    final prompt = await server.getPrompt(
        GetPromptRequest(name: 'weekly_insights', arguments: {'from': '2026-09-08', 'to': '2026-10-07'}));
    final text = (prompt.messages.single.content as TextContent).text;
    expect(text, contains('from 2026-09-08 to 2026-10-07'));
    expect(text, contains('analysis_clusters'));

    final ok = await server.callTool(CallToolRequest(
      name: 'overview',
      arguments: {'from': '2026-10-01', 'to': '2026-10-07'},
    ));
    expect(ok.isError, isNot(true));
    expect((ok.content.single as TextContent).text, '{"path":"/overview"}');

    // Missing required "to": rejected by schema validation, API never called.
    final bad = await server.callTool(CallToolRequest(name: 'overview', arguments: {'from': '2026-10-01'}));
    expect(bad.isError, isTrue);
  });
}
