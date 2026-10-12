import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/studio_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/studio_test_host.dart';

void main() {
  testWidgets('long heading and six metrics fit narrow content', (t) async {
    t.view.physicalSize = const Size(720, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      StudioHeading(
          title: List.filled(16, 'long_title').join(),
          actions: [
            FilledButton(
                onPressed: () {}, child: const Text('Refresh data'))
          ]),
      StudioGrid(
        minChildWidth: 150,
        maxColumns: 6,
        children: [
          for (var i = 0; i < 6; i++)
            StudioMetric(
                title: 'Metric $i',
                value: '123456',
                detail: 'Measured events')
        ],
      ),
    ]))));
    await t.pumpAndSettle();
    expect(find.text('Refresh data'), findsOneWidget);
    expect(find.byType(StudioMetric), findsNWidgets(6));
    expect(t.takeException(), isNull);
  });

  for (final style in AppStyle.values) {
    for (final width in [719.0, 720.0, 800.0, 1200.0]) {
      testWidgets('heading actions fit ${style.name} at $width', (t) async {
        await pumpStudio(t, StudioHeading(
          title: 'Analytics Studio overview',
          subtitle: 'Measured activity for the selected date range',
          actions: [for (var i = 0; i < 6; i++)
            FilledButton(onPressed: () {}, child: Text('Refresh data $i'))],
        ), width: width, style: style, textScale: 1.5);
        expect(t.takeException(), isNull);
        for (var i = 0; i < 6; i++) {
          final button = find.widgetWithText(FilledButton, 'Refresh data $i');
          final rect = t.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(-0.5));
          expect(rect.right, lessThanOrEqualTo(width + 0.5));
        }
      });
    }
  }

  testWidgets('long action label respects finite heading allocation', (t) async {
    final label = List.filled(120, 'X').join();
    await pumpStudio(t, StudioHeading(title: 'Overview', actions: [
      FilledButton(onPressed: () {}, child: Text(label)),
    ]), width: 720, textScale: 1.5);
    expect(t.takeException(), isNull);
    final rect = t.getRect(find.widgetWithText(FilledButton, label));
    expect(rect.left, greaterThanOrEqualTo(-0.5));
    expect(rect.right, lessThanOrEqualTo(720.5));
  });
}
