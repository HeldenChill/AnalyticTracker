import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  group('toCsv', () {
    test('formats simple grid without quotes', () {
      final res = toCsv(['A', 'B'], [
        ['1', '2'],
        ['3', '4'],
      ]);
      expect(res, equals('A,B\r\n1,2\r\n3,4'));
    });

    test('escapes quotes commas and newlines', () {
      final res = toCsv(['Header', 'Notes'], [
        ['hello, world', 'line1\nline2'],
        ['he said "yes"', 'simple'],
      ]);
      expect(
        res,
        equals('Header,Notes\r\n"hello, world","line1\nline2"\r\n"he said ""yes""",simple'),
      );
    });

    test('handles nulls and numbers', () {
      final res = toCsv(['Name', 'Score', 'Extra'], [
        ['Alice', 42, null],
      ]);
      expect(res, equals('Name,Score,Extra\r\nAlice,42,'));
    });
  });
}
