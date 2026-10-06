import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/screens/home_shell.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('refresh button refetches loaded data', (t) async {
    var calls = 0;
    await t.pumpWidget(ProviderScope(
      overrides: [
        daysProvider.overrideWith((ref) async {
          calls++;
          return [DayStat(day: '2026-10-0$calls', rowCount: calls, pulledAt: 'x')];
        }),
        eventNamesProvider.overrideWith((ref) async => const <String>[]),
        countsProvider.overrideWith((ref, q) async => const <EventCount>[]),
      ],
      child: const MaterialApp(home: HomeShell()),
    ));
    await t.pumpAndSettle();
    expect(find.text('2026-10-01'), findsOneWidget);

    await t.tap(find.byTooltip('Refresh'));
    await t.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('2026-10-02'), findsOneWidget);
  });
}
