import 'package:analytic_app/src/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final longIdentifier =
    List.filled(12, 'Reward_request_legendary_completion_').join();

Future<void> pumpStudio(
  WidgetTester t,
  Widget child, {
  double width = 720,
  double height = 1200,
  double textScale = 1.5,
  bool bold = false,
  AppStyle style = AppStyle.tremor,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: overrides,
    child: MaterialApp(
        theme: buildTheme(style),
        home: MediaQuery(
          data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(textScale),
              boldText: bold,
              disableAnimations: reducedMotion),
          child: Scaffold(body: child),
        )),
  ));
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
  }
}
