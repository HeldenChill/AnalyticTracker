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
}
