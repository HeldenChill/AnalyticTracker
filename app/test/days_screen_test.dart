import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/screens/days_screen.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Override o) => ProviderScope(
      overrides: [o],
      child: const MaterialApp(home: Scaffold(body: DaysScreen())),
    );

void main() {
  testWidgets('shows stored days and the missing gap', (t) async {
    await t.pumpWidget(host(daysProvider.overrideWith((ref) async => const [
          DayStat(day: '2026-10-01', rowCount: 10, pulledAt: 'a'),
          DayStat(day: '2026-10-03', rowCount: 5, pulledAt: 'b'),
        ])));
    await t.pumpAndSettle();
    expect(find.text('2 days stored · 1 missing'), findsOneWidget);
    expect(find.text('Missing: 2026-10-02'), findsOneWidget);
    expect(find.text('2026-10-03'), findsOneWidget);
    expect(find.text('5 events'), findsOneWidget);
  });

  testWidgets('empty store shows hint', (t) async {
    await t.pumpWidget(host(daysProvider.overrideWith((ref) async => const <DayStat>[])));
    await t.pumpAndSettle();
    expect(find.textContaining('No data yet'), findsOneWidget);
  });

  testWidgets('server error shows message and Retry', (t) async {
    await t.pumpWidget(host(daysProvider.overrideWith(
        (ref) async => throw ApiException('Cannot reach server at http://x/'))));
    await t.pumpAndSettle();
    expect(find.textContaining('Cannot reach server'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
