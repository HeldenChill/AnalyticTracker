import 'dart:async';

import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/filter_bar.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('active platform stays visible while filter options are loading', (t) async {
    final container = ProviderContainer(overrides: [
      filterOptionsProvider.overrideWith((ref) => Completer<FilterOptions>().future),
    ]);
    addTearDown(container.dispose);
    container.read(filtersProvider.notifier).setPlatform('IOS');

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: FilterBar(onRefresh: () {}))),
    ));

    expect(find.text('IOS'), findsOneWidget);
    expect(find.text('Platform: All'), findsNothing);
  });

  testWidgets('storageScope disables platform, version, test controls but retains values', (t) async {
    final container = ProviderContainer(overrides: [
      filterOptionsProvider.overrideWith((ref) async => const FilterOptions(
        platforms: ['ANDROID', 'IOS'],
        versions: ['1.0.0', '2.0.0'],
      )),
    ]);
    addTearDown(container.dispose);
    container.read(filtersProvider.notifier).setPlatform('IOS');
    container.read(filtersProvider.notifier).setVersion('2.0.0');
    container.read(filtersProvider.notifier).setIncludeTest(true);

    final initialFilters = container.read(filtersProvider);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: FilterBar(onRefresh: () {}, storageScope: true))),
    ));
    await t.pumpAndSettle();

    expect(find.text('IOS'), findsOneWidget);
    expect(find.text('2.0.0'), findsOneWidget);
    expect(find.byType(FilterChip), findsOneWidget);

    // Dropdowns have onChanged = null
    final dropdowns = t.widgetList<DropdownButton<String?>>(find.byType(DropdownButton<String?>)).toList();
    for (final d in dropdowns) {
      expect(d.onChanged, isNull);
    }

    // FilterChip onSelected = null
    final chip = t.widget<FilterChip>(find.byType(FilterChip));
    expect(chip.onSelected, isNull);

    // Filters value unchanged
    expect(container.read(filtersProvider), initialFilters);

    // Date range popup button remains active
    expect(find.byType(PopupMenuButton<int>), findsOneWidget);

    // Switch back to storageScope: false
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: FilterBar(onRefresh: () {}, storageScope: false))),
    ));
    await t.pumpAndSettle();

    final restoredDropdowns = t.widgetList<DropdownButton<String?>>(find.byType(DropdownButton<String?>)).toList();
    for (final d in restoredDropdowns) {
      expect(d.onChanged, isNotNull);
    }
    final restoredChip = t.widget<FilterChip>(find.byType(FilterChip));
    expect(restoredChip.onSelected, isNotNull);
  });
}
