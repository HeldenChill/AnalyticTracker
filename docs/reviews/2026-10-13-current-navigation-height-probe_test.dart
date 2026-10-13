import 'package:analytic_app/src/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../app/test/support/studio_matrix_fixtures.dart';
import '../../app/test/support/studio_test_host.dart';

void main() {
  testWidgets('rail remains usable at 1024 by 600', (tester) async {
    await pumpStudio(tester, const AppShell(), width: 1024, height: 600,
        overrides: studioMatrixOverrides());
    expect(tester.takeException(), isNull);
  });
}
