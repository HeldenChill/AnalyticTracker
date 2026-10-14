import 'dart:async';

import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/filter_bar.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preset preserves selected platform version and test state',
      (t) async {
    final c = ProviderContainer(overrides: [
      filterOptionsProvider.overrideWith((ref) async => const FilterOptions(
          platforms: ['IOS', 'ANDROID'], versions: ['2.0.0'])),
    ]);
    addTearDown(c.dispose);
    c.read(filtersProvider.notifier).setPlatform('IOS');
    c.read(filtersProvider.notifier).setVersion('2.0.0');
    c.read(filtersProvider.notifier).setIncludeTest(true);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child:
            MaterialApp(home: Scaffold(body: FilterBar(onRefresh: () {})))));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('filter-date-range')));
    await t.pumpAndSettle();
    await t.tap(find.text('Last 7 days').last);
    await t.pumpAndSettle();
    final f = c.read(filtersProvider);
    expect(f.platform, 'IOS');
    expect(f.version, '2.0.0');
    expect(f.includeTest, isTrue);
    expect(DateTime.parse(f.to).difference(DateTime.parse(f.from)).inDays, 6);
  });

  testWidgets(
      'toolbar displays stable keys, visible labels and default options',
      (t) async {
    final c = ProviderContainer(overrides: [
      filterOptionsProvider.overrideWith((ref) async => const FilterOptions(
          platforms: ['IOS', 'ANDROID'], versions: ['1.0.0', '2.0.0'])),
    ]);
    addTearDown(c.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: buildTheme(AppStyle.tremor),
        home: Scaffold(body: FilterBar(onRefresh: () {})),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byKey(const ValueKey('filter-date-range')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-platform')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-version')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-test-devices')), findsOneWidget);
    expect(find.byKey(const ValueKey('refresh-button')), findsOneWidget);

    expect(find.text('Date range'), findsOneWidget);
    expect(find.text('Platform'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('All platforms'), findsOneWidget);
    expect(find.text('All versions'), findsOneWidget);
    expect(find.text('Test devices'), findsOneWidget);
  });

  testWidgets(
      'bounded controls reflow cleanly at 320px width and text scale 1.5 with active filters while options loading',
      (t) async {
    final c = ProviderContainer(overrides: [
      filterOptionsProvider
          .overrideWith((ref) => Completer<FilterOptions>().future),
    ]);
    addTearDown(c.dispose);
    c.read(filtersProvider.notifier).setPlatform('IOS');
    c.read(filtersProvider.notifier).setVersion('2.1.0-build.9999+hotfix.12');

    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: buildTheme(AppStyle.shadcn),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: FilterBar(onRefresh: () {}),
            ),
          ),
        ),
      ),
    ));
    await t.pump();

    expect(find.text('IOS'), findsOneWidget);
    expect(find.text('2.1.0-build.9999+hotfix.12'), findsOneWidget);
    expect(find.byKey(const ValueKey('refresh-button')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'storageScope disables platform, version, test controls but retains values and allows date range/refresh',
      (t) async {
    final c = ProviderContainer(overrides: [
      filterOptionsProvider.overrideWith((ref) async => const FilterOptions(
          platforms: ['IOS', 'ANDROID'], versions: ['1.0.0', '2.0.0'])),
    ]);
    addTearDown(c.dispose);
    c.read(filtersProvider.notifier).setPlatform('IOS');
    c.read(filtersProvider.notifier).setVersion('2.0.0');
    c.read(filtersProvider.notifier).setIncludeTest(true);

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: buildTheme(AppStyle.midnight),
        home: Scaffold(
            body: FilterBar(onRefresh: () {}, storageScope: true)),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.text('IOS'), findsOneWidget);
    expect(find.text('2.0.0'), findsOneWidget);
    expect(find.textContaining('Storage scope:'), findsOneWidget);

    // Platform and version are now PopupMenuButton with enabled=false.
    final platformBtn = t.widget<PopupMenuButton>(
        find.byKey(const ValueKey('filter-platform')));
    expect(platformBtn.enabled, isFalse);
    final versionBtn = t.widget<PopupMenuButton>(
        find.byKey(const ValueKey('filter-version')));
    expect(versionBtn.enabled, isFalse);

    final chip = t.widget<FilterChip>(find.byType(FilterChip));
    expect(chip.onSelected, isNull);
    expect(chip.selected, isTrue);

    // Refresh and date range remain enabled.
    final btn = t.widget<OutlinedButton>(
        find.byKey(const ValueKey('refresh-button')));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets(
      'refreshing disables refresh button, shows spinner and semantic label',
      (t) async {
    final semantics = t.ensureSemantics();
    var refreshed = 0;
    final c = ProviderContainer(overrides: [
      filterOptionsProvider.overrideWith(
          (ref) async => const FilterOptions(platforms: [], versions: [])),
    ]);
    addTearDown(c.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: FilterBar(
            onRefresh: () => refreshed++,
            refreshing: true,
          ),
        ),
      ),
    ));
    await t.pump();

    final btn = t.widget<OutlinedButton>(
        find.byKey(const ValueKey('refresh-button')));
    expect(btn.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Refreshing data'), findsOneWidget);

    // Tapping while refreshing does not invoke callback
    await t.tap(find.byKey(const ValueKey('refresh-button')));
    expect(refreshed, 0);

    semantics.dispose();
  });
}
