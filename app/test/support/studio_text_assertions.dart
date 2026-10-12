import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void expectCompleteSingleLine(WidgetTester t, Finder finder) {
  final p = t.renderObject<RenderParagraph>(finder);
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textAlign: p.textAlign,
    textScaler: p.textScaler,
    locale: p.locale,
    maxLines: 1,
  )..layout();
  expect(p.size.width + 0.5, greaterThanOrEqualTo(painter.width),
      reason: 'Every numeric glyph must fit; horizontal scrolling cannot restore clipped digits.');
  expect(p.didExceedMaxLines, isFalse);
  painter.dispose();
}

void expectCompleteWrappedText(WidgetTester t, Finder finder) {
  final p = t.renderObject<RenderParagraph>(finder);
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textAlign: p.textAlign,
    textScaler: p.textScaler,
    locale: p.locale,
  )..layout(maxWidth: p.size.width);
  expect(p.size.height + 0.5, greaterThanOrEqualTo(painter.height),
      reason: 'The full wrapped paragraph must fit vertically.');
  expect(p.didExceedMaxLines, isFalse);
  painter.dispose();
}
