import 'package:analytic_app/src/pages/funnel_page.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../app/test/funnel_page_test.dart' as fixture;
import '../../app/test/support/studio_test_host.dart';

void main() {
  for (final menu in [false, true]) {
    testWidgets('full saved Funnel name readable in ${menu ? 'menu' : 'selected value'}', (t) async {
      final prefix = List.filled(20, 'Reward_request_legendary_completion_').join();
      final alpha = '${prefix}Alpha';
      final beta = '${prefix}Beta';
      await pumpStudio(t, const FunnelPage(), width: 720, textScale: 1.5, overrides: [
        savedFunnelsProvider.overrideWith((ref) async => [
          SavedFunnel(id: 1, name: alpha, windowMinutes: 1440, steps: fixture.steps, updatedAt: 'x'),
          SavedFunnel(id: 2, name: beta, windowMinutes: 1440, steps: fixture.steps, updatedAt: 'x'),
        ]),
        funnelResultProvider.overrideWith((ref, q) async => fixture.result),
      ]);
      expect(t.takeException(), isNull);
      final dropdown = find.byType(DropdownButton<int>);
      if (menu) {
        await t.tap(dropdown);
        await t.pumpAndSettle();
      }
      final text = menu ? find.text(beta).last : find.descendant(of: dropdown, matching: find.text(alpha)).first;
      final paragraph = t.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse,
        reason: 'names differing only in suffix must stay distinguishable');
    });
  }
}
