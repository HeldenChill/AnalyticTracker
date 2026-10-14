import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/filter_bar.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_text_assertions.dart';

bool _focusedWithin(WidgetTester t, String key) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final control = t.element(find.byKey(ValueKey(key)));
  var inside = identical(focused, control);
  focused.visitAncestorElements((ancestor) {
    inside |= identical(ancestor, control);
    return !inside;
  });
  return inside;
}

class _Filters extends FiltersNotifier {
  @override
  Filters build() => const Filters(
      from: '2026-10-01',
      to: '2026-10-04',
      platform: 'IOS',
      version: '2.0',
      includeTest: true);
}

Future<ProviderContainer> _pump(WidgetTester t,
    {AppStyle style = AppStyle.tremor,
    double width = 720,
    bool optionsFail = false,
    String? unknownVersion,
    VoidCallback? onRefresh}) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = ProviderContainer(overrides: [
    filtersProvider.overrideWith(_Filters.new),
    filterOptionsProvider.overrideWith((ref) async {
      if (optionsFail) throw StateError('options offline');
      return const FilterOptions(platforms: [
        'IOS',
        'ANDROID'
      ], versions: [
        '2.0',
        '2.1.0-build.9999+hotfix.alpha',
        '2.1.0-build.9999+hotfix.beta'
      ]);
    }),
  ]);
  addTearDown(c.dispose);
  if (unknownVersion != null) {
    c.read(filtersProvider.notifier).setVersion(unknownVersion);
  }
  await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
          theme: buildTheme(style),
          home: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 1000),
                textScaler: const TextScaler.linear(1.5)),
            child: Scaffold(
                body: Align(
                    alignment: Alignment.topLeft,
                    child: FilterBar(onRefresh: onRefresh ?? () {}))),
          ))));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('narrow date control displays both selected dates completely',
      (t) async {
    await _pump(t, width: 320);
    expectCompleteWrappedText(t, find.text('2026-10-01 → 2026-10-04'));
  });
  for (final style in AppStyle.values) {
    testWidgets(
        '${style.name} narrow version menu exposes distinct suffix and selected tooltip',
        (t) async {
      final c = await _pump(t, style: style, width: 320);
      await t.tap(find.byKey(const ValueKey('filter-version')));
      await t.pumpAndSettle();
      const alpha = '2.1.0-build.9999+hotfix.alpha';
      const beta = '2.1.0-build.9999+hotfix.beta';
      expectCompleteWrappedText(t, find.text(alpha).last);
      expectCompleteWrappedText(t, find.text(beta).last);
      await t.tap(find.text(beta).last);
      await t.pumpAndSettle();
      expect(c.read(filtersProvider).version, beta);
      expect(find.byTooltip(beta), findsOneWidget);
      final tooltip =
          find.byWidgetPredicate((w) => w is Tooltip && w.message == beta);
      final state = t.state<TooltipState>(tooltip);
      state.ensureTooltipVisible();
      await t.pumpAndSettle();
      expect(
          find.text(beta),
          findsNWidgets(
              2)); // Compact selected text plus actual full disclosure.
    });
  }

  testWidgets('failed options retain unknown saved value with full disclosure',
      (t) async {
    const unknown = '3.0.0-unlisted-long-production-release';
    final c = await _pump(t, optionsFail: true, unknownVersion: unknown);
    expect(c.read(filtersProvider).version, unknown);
    expect(find.byTooltip(unknown), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('filter-version')));
    await t.pumpAndSettle();
    expectCompleteWrappedText(t, find.text(unknown).last);
    await t.tap(find.text('All versions').last);
    await t.pumpAndSettle();
    expect(c.read(filtersProvider).version, isNull);
    expect(c.read(filtersProvider).platform, 'IOS');
    expect(c.read(filtersProvider).includeTest, isTrue);
  });

  for (final accept in [false, true]) {
    testWidgets(
        'custom date input ${accept ? 'applies actual dates' : 'cancellation keeps original dates'}',
        (t) async {
      final c = await _pump(t);
      final before = c.read(filtersProvider);
      await t.tap(find.byKey(const ValueKey('filter-date-range')));
      await t.pumpAndSettle();
      await t.tap(find.text('Custom…'));
      await t.pumpAndSettle();
      final dialog = find.byType(DateRangePickerDialog);
      expect(dialog, findsOneWidget);
      final loc = MaterialLocalizations.of(t.element(dialog));
      await t.tap(find.byTooltip(loc.inputDateModeButtonLabel));
      await t.pumpAndSettle();
      final start = find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.labelText == loc.dateRangeStartLabel);
      final end = find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.labelText == loc.dateRangeEndLabel);
      await t.enterText(start, '10/02/2026');
      await t.enterText(end, '10/03/2026');
      await t.tap(
          find.text(accept ? loc.okButtonLabel : loc.cancelButtonLabel).last);
      await t.pumpAndSettle();
      expect(dialog, findsNothing);
      final after = c.read(filtersProvider);
      expect(after.from, accept ? '2026-10-02' : before.from);
      expect(after.to, accept ? '2026-10-03' : before.to);
      expect(after.platform, 'IOS');
      expect(after.version, '2.0');
      expect(after.includeTest, isTrue);
    });
  }

  testWidgets('keyboard traversal operates actual scope controls and refresh',
      (t) async {
    var refreshed = 0;
    final c = await _pump(t, onRefresh: () => refreshed++);
    final reached = <String>{};
    const keys = [
      'filter-date-range',
      'filter-platform',
      'filter-version',
      'filter-test-devices',
      'refresh-button'
    ];
    for (var i = 0; i < 12; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      for (final key in keys) {
        if (_focusedWithin(t, key)) reached.add(key);
      }
    }
    expect(reached, containsAll(keys));
    final before = c.read(filtersProvider).includeTest;
    for (var i = 0; i < 12; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      if (_focusedWithin(t, 'filter-test-devices')) break;
    }
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pumpAndSettle();
    expect(c.read(filtersProvider).includeTest, !before);
    for (var i = 0; i < 12; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      if (_focusedWithin(t, 'filter-platform')) break;
    }
    expect(_focusedWithin(t, 'filter-platform'), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(c.read(filtersProvider).platform, 'ANDROID');
    for (var i = 0; i < 12; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      if (_focusedWithin(t, 'refresh-button')) break;
    }
    expect(_focusedWithin(t, 'refresh-button'), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(refreshed, 1);
  });
}
