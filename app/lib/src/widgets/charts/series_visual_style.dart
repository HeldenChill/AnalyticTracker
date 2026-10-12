import 'package:flutter/material.dart';

class SeriesVisualStyle {
  const SeriesVisualStyle({
    required this.color,
    required this.lineDash,
    required this.rodBorder,
  });

  final Color color;
  final List<int>? lineDash;
  final BorderSide rodBorder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeriesVisualStyle &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          _listEquals(lineDash, other.lineDash) &&
          rodBorder == other.rodBorder;

  @override
  int get hashCode => Object.hash(color, Object.hashAll(lineDash ?? const []), rodBorder);

  static bool _listEquals(List<int>? a, List<int>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

SeriesVisualStyle resolveSeriesVisualStyle({
  required List<Color> palette,
  required int slot,
  required String seriesId,
  required Color outline,
}) {
  if (palette.isEmpty || slot < 0) throw ArgumentError('Invalid series style input');
  final cycle = slot ~/ palette.length;
  final reference = seriesId == 'previous' || seriesId == 'alert-baseline';
  final patterns = <List<int>?>[null, [6, 4], [2, 4], [8, 3, 2, 3]];
  final outlineCycle = cycle > 0 ? cycle : 1;
  return SeriesVisualStyle(
    color: palette[slot % palette.length],
    lineDash: reference ? const [6, 4] : patterns[cycle % patterns.length],
    rodBorder: cycle == 0 && !reference
        ? BorderSide.none
        : BorderSide(
            color: outline,
            width: (((outlineCycle - 1) % 3) + 1).toDouble(),
          ),
  );
}

String describeSeriesVisualStyle(
  SeriesVisualStyle style, {
  required bool isBars,
  required String seriesId,
}) {
  final reference = seriesId == 'previous' || seriesId == 'alert-baseline';
  if (isBars) {
    if (style.rodBorder != BorderSide.none) {
      return reference ? 'reference outlined' : 'outlined';
    }
    return reference ? 'reference solid' : 'solid';
  } else {
    if (reference) return 'reference dashed';
    if (style.lineDash == null) return 'solid';
    if (style.lineDash!.length == 2 && style.lineDash![0] == 2) return 'dotted';
    return 'dashed';
  }
}

class SeriesSamplePainter extends CustomPainter {
  const SeriesSamplePainter({
    required this.style,
    required this.isBars,
  });

  final SeriesVisualStyle style;
  final bool isBars;

  @override
  void paint(Canvas canvas, Size size) {
    if (isBars) {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      final fillPaint = Paint()
        ..color = style.color
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, fillPaint);
      if (style.rodBorder != BorderSide.none) {
        final borderPaint = Paint()
          ..color = style.rodBorder.color
          ..strokeWidth = style.rodBorder.width
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(rrect, borderPaint);
      }
    } else {
      final paint = Paint()
        ..color = style.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final y = size.height / 2;
      final dash = style.lineDash;
      if (dash == null || dash.isEmpty) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      } else {
        var x = 0.0;
        var dashIndex = 0;
        var draw = true;
        while (x < size.width) {
          final len = dash[dashIndex % dash.length].toDouble();
          final nextX = (x + len).clamp(0.0, size.width);
          if (draw) {
            canvas.drawLine(Offset(x, y), Offset(nextX, y), paint);
          }
          x = nextX;
          dashIndex++;
          draw = !draw;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SeriesSamplePainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.isBars != isBars;
  }
}
