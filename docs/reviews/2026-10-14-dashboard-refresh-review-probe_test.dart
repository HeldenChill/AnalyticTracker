import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/charts/chart_models.dart';
import 'package:analytic_app/src/widgets/dashboard_chart_panel.dart';
import 'package:analytic_app/src/widgets/filter_bar.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long filter menu versions disclose complete distinct suffixes',
      (t) async {
    const alpha = '2.1.0-build.9999+hotfix.alpha';
    const beta = '2.1.0-build.9999+hotfix.beta';
    t.view.physicalSize = const Size(720, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
        overrides: [
          filterOptionsProvider.overrideWith((ref) async =>
              const FilterOptions(platforms: ['IOS'], versions: [alpha, beta])),
        ],
        child: MaterialApp(
            theme: buildTheme(AppStyle.tremor),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(
                  body: Align(
                      alignment: Alignment.topLeft,
                      child: FilterBar(onRefresh: () {}))),
            ))));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('filter-version')));
    await t.pumpAndSettle();
    for (final label in [alpha, beta]) {
      final paragraph = t.renderObject<RenderParagraph>(find.text(label).last);
      expect(paragraph.didExceedMaxLines, isFalse,
          reason:
              'Menu must show distinct version suffixes; full Text widget presence is insufficient.');
    }
  });

  for (final changeTheme in [false, true]) {
    testWidgets(
        'collapsed chart data preserves horizontal position; theme rebuild=$changeTheme',
        (t) async {
      t.view.physicalSize = const Size(320, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final bucket = PageStorageBucket();
      final selectedTheme = ValueNotifier<AppStyle>(AppStyle.tremor);
      addTearDown(selectedTheme.dispose);
      await t.pumpWidget(ValueListenableBuilder<AppStyle>(
        valueListenable: selectedTheme,
        builder: (context, style, child) => MaterialApp(
          theme: buildTheme(style),
          themeAnimationDuration: Duration.zero,
          home: PageStorage(
              bucket: bucket,
              child: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: const Scaffold(
                    body: SingleChildScrollView(
                        child: DashboardChartPanel(
                            key: ValueKey('review-panel'),
                            title: 'Review data',
                            subtitle: 'Retained scroll',
                            unit: 'players',
                            series: ChartSeries(
                                id: 'primary',
                                label: 'Players',
                                points: [
                                  ChartPoint(1, 123456789, label: '2026-10-01'),
                                  ChartPoint(2, 234567890, label: '2026-10-02'),
                                ])))),
              )),
        ),
      ));
      await t.pumpAndSettle();
      await t.tap(find.text('View data'));
      await t.pumpAndSettle();
      Finder horizontal() => find.descendant(
          of: find.byKey(const ValueKey('review-panel')),
          matching: find.byWidgetPredicate((w) =>
              w is Scrollable &&
              axisDirectionToAxis(w.axisDirection) == Axis.horizontal));
      final initial = t.state<ScrollableState>(horizontal());
      expect(initial.position.maxScrollExtent, greaterThan(0));
      final offset = initial.position.maxScrollExtent;
      initial.position.jumpTo(offset);
      await t.pumpAndSettle();
      await t.tap(find.text('View data'));
      await t.pumpAndSettle();
      expect(horizontal(), findsNothing);
      if (changeTheme) {
        selectedTheme.value = AppStyle.midnight;
        await t.pumpAndSettle();
      }
      await t.tap(find.text('View data'));
      await t.pumpAndSettle();
      expect(t.state<ScrollableState>(horizontal()).position.pixels,
          closeTo(offset, .5),
          reason:
              'Changing theme while collapsed must not discard chart-data scroll storage.');
    });
  }
}
