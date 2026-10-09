import 'package:dart_mcp/server.dart';

import 'mcp_prompts.dart';
import 'mcp_tools.dart';

/// MCP server exposing [AnalyticTools] and the `weekly_insights` prompt over
/// any string channel (stdio in `bin/mcp.dart`, an in-memory channel in tests).
base class AnalyticMcpServer extends MCPServer with ToolsSupport, PromptsSupport {
  AnalyticMcpServer(super.channel, this.tools)
      : super.fromStreamChannel(
          implementation: Implementation(name: 'analytic-tracker', version: '0.1.0'),
          instructions: 'AnalyticTracker game analytics (PetVsMonster). Dates are YYYY-MM-DD. '
              'Test-device events are excluded unless include_test is true. '
              'Call data_health first if numbers look low; import_export defaults to a dry run.',
        ) {
    for (final MapEntry(key: name, value: (tool, _)) in tools.all.entries) {
      registerTool(tool, (request) => tools.call(name, request.arguments ?? const {}));
    }
    addPrompt(weeklyInsightsPrompt, (request) => weeklyInsights(tools.all.keys, request.arguments));
  }

  final AnalyticTools tools;
}
