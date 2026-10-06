import 'package:analytic_app/src/screens/settings_screen.dart';
import 'package:analytic_app/src/state/style.dart';
import 'package:analytic_app/src/theme/analytics_tokens.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('KpiCard uses style good/bad tokens', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(AppStyle.midnight),
      home: const Scaffold(body: Column(children: [
        KpiCard(title: 'DAU', value: '1', delta: 0.1),
        KpiCard(title: 'Uninstalls', value: '1', delta: 0.1, higherIsBetter: false),
      ])),
    ));
    expect(t.widget<Text>(find.text('▲ 10% vs prev').first).style!.color, const Color(0xFF34D399));
    expect(t.widget<Text>(find.text('▲ 10% vs prev').last).style!.color, const Color(0xFFFB7185));
  });

  testWidgets('Settings style card switches theme and persists', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});

    await t.pumpWidget(ProviderScope(
      child: Consumer(builder: (context, ref, _) => MaterialApp(
            theme: buildTheme(ref.watch(styleProvider)),
            home: const Scaffold(body: SettingsScreen()),
          )),
    ));
    for (final s in AppStyle.values) {
      expect(find.text(s.label), findsOneWidget);
    }

    await t.tap(find.text('Midnight Game'));
    await t.pumpAndSettle();

    final ctx = t.element(find.byType(SettingsScreen));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(AnalyticsTokens.of(ctx).chart.first, const Color(0xFF22D3EE));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(stylePrefKey), 'midnight');
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
