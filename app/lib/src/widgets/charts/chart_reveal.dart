import 'package:flutter/rendering.dart';

double revealValue(double baseline, double target, double progress) =>
    baseline + (target - baseline) * progress.clamp(0.0, 1.0);

class ChartRevealClip extends CustomClipper<Rect> {
  const ChartRevealClip({required this.progress, required this.plot});

  final double progress;
  final Rect plot;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        plot.left,
        plot.top,
        plot.left + plot.width * progress.clamp(0.0, 1.0),
        plot.bottom,
      );

  @override
  bool shouldReclip(ChartRevealClip oldClipper) =>
      oldClipper.progress != progress || oldClipper.plot != plot;
}
