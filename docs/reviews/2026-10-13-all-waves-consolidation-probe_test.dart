import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/studio_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../app/test/support/studio_matrix_fixtures.dart';
import '../../app/test/support/studio_test_host.dart';
import '../../app/test/support/studio_text_assertions.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Inter': ['400', '700'], 'Geist': ['400', '700'],
      'Manrope': ['400', '700'], 'ChakraPetch': ['500', '700'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final weight in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/${entry.key}-$weight.ttf'));
      }
      await loader.load();
    }
  });
  for (final style in AppStyle.values) {
    testWidgets('bold numeric paragraph fits ${style.name}', (t) async {
      await pumpStudio(t, Builder(builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(boldText: true),
        child: const StudioTable(columns: [StudioColumn('Players', width: 80, numeric: true)],
          rows: [StudioRow([StudioTextCell('123456789012', numeric: true,
            style: TextStyle(fontWeight: FontWeight.w400))])]),
      )), style: style, textScale: 1.5);
      expectCompleteSingleLine(t, find.text('123456789012'));
    });
  }
  testWidgets('1024 width uses approved NavigationRail', (t) async {
    await pumpStudio(t, const AppShell(), width: 1024,
      overrides: studioMatrixOverrides());
    expect(find.byType(NavigationRail), findsOneWidget);
  });
  testWidgets('720 width exposes approved menu app bar', (t) async {
    await pumpStudio(t, const AppShell(), width: 720,
      overrides: studioMatrixOverrides());
    expect(find.byType(AppBar), findsOneWidget);
  });
}
