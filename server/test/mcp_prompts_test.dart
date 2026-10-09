import 'package:analytic_server/analytic_server.dart';
import 'package:dart_mcp/server.dart';
import 'package:test/test.dart';

String textOf(GetPromptResult r) => (r.messages.single.content as TextContent).text;

void main() {
  const names = ['data_health', 'overview', 'analysis_clusters', 'analysis_churn'];

  test('weekly_insights lists every analysis_* tool and the given range', () {
    final r = weeklyInsights(names, {'from': '2026-09-08', 'to': '2026-10-07'});
    final text = textOf(r);
    expect(r.messages.single.role, Role.user);
    expect(text, contains('from 2026-09-08 to 2026-10-07'));
    expect(text, contains(': analysis_clusters, analysis_churn.'));
    expect(text, contains('fewer than 10 players is a small sample'));
    expect(r.description, 'Weekly insights from 2026-09-08 to 2026-10-07');
  });

  test('weekly_insights without a full range asks Claude to find the last stored day', () {
    for (final args in [null, <String, Object?>{}, {'from': '2026-09-08'}]) {
      expect(textOf(weeklyInsights(names, args)), contains('last 30 days of stored data'), reason: '$args');
    }
  });

  test('weekly_insights prompt metadata', () {
    expect(weeklyInsightsPrompt.name, 'weekly_insights');
    expect(weeklyInsightsPrompt.arguments!.map((a) => a.name), ['from', 'to']);
  });
}
