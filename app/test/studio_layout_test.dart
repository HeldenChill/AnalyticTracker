import 'package:analytic_app/src/widgets/studio_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
