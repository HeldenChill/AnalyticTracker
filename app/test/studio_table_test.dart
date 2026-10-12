import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/studio_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_test_host.dart';

void main() {
  for (final style in AppStyle.values) {
    testWidgets('table wraps long identifiers in ${style.name}', (t) async {
      await pumpStudio(
          t,
          StudioTable(
            columns: const [
              StudioColumn('An unusually long descriptive event title',
                  width: 220),
              StudioColumn('Occurrences', numeric: true, width: 180),
            ],
            rows: [
              StudioRow([
                StudioTextCell(longIdentifier),
                const StudioTextCell('123456789012', numeric: true),
              ])
            ],
          ),
          style: style);
      expect(find.text(longIdentifier), findsOneWidget);
      expect(find.text('123456789012'), findsOneWidget);
      final text = t.renderObject<RenderBox>(find.text(longIdentifier));
      expect(text.size.width, lessThanOrEqualTo(220));
      expect(text.size.height, greaterThan(48));
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
