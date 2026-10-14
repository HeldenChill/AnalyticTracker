import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/theme/app_style.dart';
import 'package:analytic_app/src/widgets/filter_bar.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pump a FilterBar host with fixed dimensions and filter options.
Future<ProviderContainer> _pumpFilterBar(
  WidgetTester t, {
  required double width,
  AppStyle style = AppStyle.tremor,
  double textScale = 1.0,
}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = ProviderContainer(overrides: [
    filterOptionsProvider.overrideWith((ref) async => const FilterOptions(
          platforms: ['IOS', 'ANDROID'],
          versions: ['2.0', '2.1.0-build.9999+hotfix.alpha'],
        )),
  ]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      theme: buildTheme(style),
      home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 800), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
                key: const ValueKey('filter-pixels'),
                child: FilterBar(onRefresh: () {})),
          ),
        ),
      ),
    ),
  ));
  await t.pumpAndSettle();
  return c;
}

void main() {
  // Geometry gate: all three trigger controls must be at least 44 logical px
  // tall at all tested viewport widths and text scales, matching the min-height
  // constraint in FilterTrigger.
  for (final style in AppStyle.values) {
    for (final width in [320.0, 720.0, 1024.0, 1440.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
            '${style.name} w=$width scale=$scale: all three triggers >= 44px height',
            (t) async {
          await _pumpFilterBar(t, width: width, style: style, textScale: scale);

          final date = find.byKey(const ValueKey('filter-date-range'));
          final platform = find.byKey(const ValueKey('filter-platform'));
          final version = find.byKey(const ValueKey('filter-version'));

          expect(t.getSize(date).height, greaterThanOrEqualTo(44),
              reason: 'date trigger must be >= 44px');
          expect(t.getSize(platform).height, greaterThanOrEqualTo(44),
              reason: 'platform trigger must be >= 44px');
          expect(t.getSize(version).height, greaterThanOrEqualTo(44),
              reason: 'version trigger must be >= 44px');
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  // No horizontal overflow at any width.
  for (final width in [320.0, 720.0, 1024.0, 1440.0]) {
    testWidgets('no overflow at width $width', (t) async {
      await _pumpFilterBar(t, width: width);
      expect(t.takeException(), isNull);
    });
  }

  // Hover feedback test: moving pointer into a trigger changes at least one
  // interior pixel (hover ink is active) and corner pixels outside the
  // quarter-circle arc remain unchanged (rounded clip works).
  testWidgets('hover ink changes interior pixel but not corner outside radius',
      (t) async {
    // Use a wide viewport so the toolbar fits in one row without wrapping.
    await _pumpFilterBar(t, width: 1024, style: AppStyle.tremor);

    final date = find.byKey(const ValueKey('filter-date-range'));
    final center = t.getCenter(date);
    final rect = t.getRect(date);

    final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('filter-pixels')));
    Future<List<int>> pixels() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List().toList();
    }

    final before = (await t.runAsync(pixels))!;
    final pointer = await t.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(pointer.removePointer);
    await pointer.addPointer(location: Offset.zero);
    await pointer.moveTo(center);
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    final after = (await t.runAsync(pixels))!;
    final origin = boundary.localToGlobal(Offset.zero);
    final local = rect.shift(-origin);
    final imageWidth = boundary.size.width.round();
    bool changed(int x, int y) {
      final offset = (y * imageWidth + x) * 4;
      return List.generate(4, (i) => before[offset + i] != after[offset + i])
          .any((v) => v);
    }

    final left = local.left.round();
    final top = local.top.round();
    expect(changed(left + 1, top + 1), isFalse,
        reason: 'hover must not paint outside rounded corner');
    var interiorChanged = false;
    for (var y = top + 5; y < local.bottom - 5; y++) {
      for (var x = left + 10; x < local.right - 10; x++) {
        interiorChanged |= changed(x, y);
      }
    }
    expect(interiorChanged, isTrue,
        reason: 'oracle must observe real hover ink');
    expect(t.takeException(), isNull);
  });

  // storageScope: disabled triggers still render at >= 44px height.
  testWidgets('storageScope triggers still >= 44px and show hint', (t) async {
    t.view.physicalSize = const Size(720, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = ProviderContainer(overrides: [
      filterOptionsProvider.overrideWith((ref) async => const FilterOptions(
            platforms: ['IOS'],
            versions: ['2.0'],
          )),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: FilterBar(onRefresh: () {}, storageScope: true),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    final platform = find.byKey(const ValueKey('filter-platform'));
    final version = find.byKey(const ValueKey('filter-version'));
    expect(t.getSize(platform).height, greaterThanOrEqualTo(44));
    expect(t.getSize(version).height, greaterThanOrEqualTo(44));
    expect(find.textContaining('Storage scope:'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
