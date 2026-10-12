import 'package:flutter/material.dart';

enum MotionKind {
  navigation,
  tab,
  expansion,
  chartEnter,
  chartUpdate,
  theme,
  hover,
}

Duration motionDuration(BuildContext context, MotionKind kind) {
  final media = MediaQuery.maybeOf(context);
  if (media != null && (media.disableAnimations || media.accessibleNavigation)) {
    return Duration.zero;
  }
  return switch (kind) {
    MotionKind.navigation => const Duration(milliseconds: 180),
    MotionKind.tab => const Duration(milliseconds: 200),
    MotionKind.expansion => const Duration(milliseconds: 220),
    MotionKind.chartEnter => const Duration(milliseconds: 400),
    MotionKind.chartUpdate => const Duration(milliseconds: 350),
    MotionKind.theme => const Duration(milliseconds: 200),
    MotionKind.hover => const Duration(milliseconds: 120),
  };
}
