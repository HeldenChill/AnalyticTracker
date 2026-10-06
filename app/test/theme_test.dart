import 'package:analytic_app/src/state/style.dart';
import 'package:analytic_app/src/theme/analytics_tokens.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every style builds a theme with tokens matching the palette', () {
    final expected = {
      AppStyle.tremor: (Brightness.light, const Color(0xFFF9FAFB), const Color(0xFF3B82F6), 12.0),
      AppStyle.shadcn: (Brightness.light, const Color(0xFFFFFFFF), const Color(0xFF18181B), 10.0),
      AppStyle.midnight: (Brightness.dark, const Color(0xFF0B1020), const Color(0xFF22D3EE), 12.0),
      AppStyle.material: (Brightness.light, const Color(0xFFF2F4FA), const Color(0xFF3559E0), 20.0),
    };
    for (final s in AppStyle.values) {
      final t = buildTheme(s);
      final (brightness, bg, accent, radius) = expected[s]!;
      final tokens = t.extension<AnalyticsTokens>()!;
      expect(t.brightness, brightness, reason: s.name);
      expect(t.scaffoldBackgroundColor, bg, reason: s.name);
      expect(t.colorScheme.primary, accent, reason: s.name);
      expect(tokens.chart.first, accent, reason: s.name);
      expect(tokens.chart.length, 4, reason: s.name);
      expect(tokens.radius, radius, reason: s.name);
      expect(t.textTheme.bodyMedium!.fontFamily, palettes[s]!.bodyFont, reason: s.name);
      expect(t.textTheme.titleLarge!.fontFamily, palettes[s]!.displayFont, reason: s.name);
    }
  });

  test('parseStyle falls back to Tremor Light', () {
    expect(parseStyle('midnight'), AppStyle.midnight);
    expect(parseStyle('bogus'), AppStyle.tremor);
    expect(parseStyle(null), AppStyle.tremor);
  });

  test('StyleNotifier.select updates state and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(styleProvider), AppStyle.tremor);
    await c.read(styleProvider.notifier).select(AppStyle.shadcn);
    expect(c.read(styleProvider), AppStyle.shadcn);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(stylePrefKey), 'shadcn');
  });

  testWidgets('AnalyticsTokens.of falls back without the extension', (t) async {
    late AnalyticsTokens tokens;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      tokens = AnalyticsTokens.of(context);
      return const SizedBox();
    })));
    expect(tokens.good, Colors.green);
    expect(tokens.bad, Colors.red);
  });
}
