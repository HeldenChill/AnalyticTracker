import 'package:analytic_app/src/theme/analytics_tokens.dart';
import 'package:analytic_app/src/widgets/funnel_trend_view.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_matrix_fixtures.dart';
import 'support/studio_test_host.dart';

void main() {
  testWidgets('export bytes and displayed partial bucket match fixture',
      (t) async {
    String? clipboard;
    t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpStudio(
        t,
        FunnelTrendView(
            result: matrixFunnelResult('start'),
            interval: FunnelInterval.week,
            onIntervalChanged: (_) {}),
        width: 720,
        textScale: 1.5,
        reducedMotion: true);
    final partial = find.byKey(const ValueKey('entered-bar-2026-10-05'));
    final complete = find.byKey(const ValueKey('entered-bar-2026-09-28'));
    expect(partial, findsOneWidget);
    expect(complete, findsOneWidget);
    final p = t.widget<Container>(partial).decoration! as BoxDecoration;
    final c = t.widget<Container>(complete).decoration! as BoxDecoration;
    expect(p.color!.a, closeTo(.4, .01));
    expect(c.color!.a, closeTo(.85, .01));
    expect(t.getSize(partial).height, closeTo(50 * 4 / 6, .01));
    expect(t.getSize(complete).height, 50);
    expect(find.text('Partial bucket — may be incomplete'), findsOneWidget);
    final sample =
        t.widget<Container>(find.byKey(const ValueKey('partial-trend-sample')));
    final tokens = AnalyticsTokens.of(t.element(partial));
    expect((sample.decoration! as BoxDecoration).color,
        tokens.chart.first.withValues(alpha: .4));
    expect(find.byTooltip('2026-10-05: 4 entered (partial)'), findsOneWidget);
    await t.tap(find.text('Copy CSV'));
    await t.pump();
    expect(
        clipboard,
        'Start,Step 1,Step 2,Total conversion,Incomplete\r\n'
        '2026-09-28,6,3,50%,false\r\n2026-10-05,4,2,50%,true');
  });
}
