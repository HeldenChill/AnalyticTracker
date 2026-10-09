import 'package:dart_mcp/server.dart';

/// `weekly_insights` MCP prompt (spec .cursor/plans/analytic-tab-design.md §8a).
final weeklyInsightsPrompt = Prompt(
  name: 'weekly_insights',
  title: 'Weekly insights',
  description: 'Top 5 findings about players from every Analytic tool, with evidence and sample sizes.',
  arguments: [
    PromptArgument(name: 'from', description: 'First day, YYYY-MM-DD. Default: 29 days before "to".'),
    PromptArgument(name: 'to', description: 'Last day, YYYY-MM-DD. Default: the last stored day.'),
  ],
);

/// Prompt text for [toolNames] (every registered tool; the `analysis_*` ones
/// are listed by name) and the optional `from` / `to` arguments.
GetPromptResult weeklyInsights(Iterable<String> toolNames, Map<String, Object?>? args) {
  final analysis = [for (final n in toolNames) if (n.startsWith('analysis_')) n];
  final from = args?['from'] as String?;
  final to = args?['to'] as String?;
  final range = (from != null && to != null)
      ? 'from $from to $to'
      : 'over the last 30 days of stored data (call data_health; "to" = the last stored day, '
          '"from" = 29 days before it)';
  final text = '''
Write the top 5 insights about PetVsMonster players $range.

1. Call data_health first and mention gaps in the range, if any.
2. Call each Analytic tool with that range (include_test false): ${analysis.join(', ')}.
   You may also call overview, retention or run_funnel for context.
3. If a tool returns a "reason" (too_few_players, no_variance), report that instead of guessing.
4. Rank findings by impact times sample size. Write each as one plain sentence, then the evidence
   numbers and the number of players (n).
5. A group of fewer than 10 players is a small sample: say so, and never state it as a fact.
6. Link related findings across tools when they describe the same players.
''';
  return GetPromptResult(
    description: 'Weekly insights $range',
    messages: [PromptMessage(role: Role.user, content: TextContent(text: text))],
  );
}
