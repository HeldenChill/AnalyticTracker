import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  test('FunnelInterval parse and wire values', () {
    expect(FunnelInterval.parse('day'), FunnelInterval.day);
    expect(FunnelInterval.parse('week'), FunnelInterval.week);
    expect(() => FunnelInterval.parse('month'), throwsFormatException);
    expect(FunnelInterval.day.wire, 'day');
    expect(FunnelInterval.week.wire, 'week');
    expect(FunnelInterval.day.label, 'Day');
    expect(FunnelInterval.week.label, 'Week');
  });

  test('FunnelTrendPoint toJson and fromJson round trip', () {
    const pt = FunnelTrendPoint(
      start: '2026-10-01',
      players: [10, 5, 2],
      totalConversion: 0.2,
      incomplete: false,
    );
    final j = pt.toJson();
    expect(j, {
      'start': '2026-10-01',
      'players': [10, 5, 2],
      'totalConversion': 0.2,
      'incomplete': false,
    });
    final parsed = FunnelTrendPoint.fromJson(j);
    expect(parsed.start, '2026-10-01');
    expect(parsed.players, [10, 5, 2]);
    expect(parsed.totalConversion, 0.2);
    expect(parsed.incomplete, isFalse);
  });

  test('FunnelTrendPoint equality and null conversion for zero entries', () {
    const emptyPt = FunnelTrendPoint(
      start: '2026-10-02',
      players: [0, 0, 0],
      totalConversion: null,
      incomplete: true,
    );
    final j = emptyPt.toJson();
    final parsed = FunnelTrendPoint.fromJson(j);
    expect(parsed, emptyPt);
    expect(parsed.totalConversion, isNull);
    expect(parsed.incomplete, isTrue);
  });

  test('FunnelResult with trend serializes and deserializes', () {
    const pt = FunnelTrendPoint(
      start: '2026-10-05',
      players: [20, 10],
      totalConversion: 0.5,
      incomplete: false,
    );
    final res = FunnelResult(
      steps: const [
        FunnelStepResult(
          index: 0,
          event: 'start',
          players: 20,
          fromPrevious: null,
          fromFirst: 1.0,
          dropped: null,
          medianSeconds: null,
        ),
      ],
      totalConversion: 0.5,
      biggestDropIndex: null,
      trend: const [pt],
    );

    final json = res.toJson();
    expect(json['trend'], isNotEmpty);

    final fromJson = FunnelResult.fromJson(json);
    expect(fromJson.trend.length, 1);
    expect(fromJson.trend.first.start, '2026-10-05');
    expect(fromJson.trend.first.players, [20, 10]);
    expect(fromJson.trend.first.totalConversion, 0.5);
    expect(fromJson.trend.first.incomplete, isFalse);
  });

  test('FunnelResult omits trend in json when empty', () {
    const res = FunnelResult(
      steps: [],
      totalConversion: null,
      biggestDropIndex: null,
    );
    expect(res.toJson().containsKey('trend'), isFalse);
  });
}
