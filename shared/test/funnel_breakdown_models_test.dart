import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  test('FunnelBreakdownBy parse and wire round trip', () {
    expect(FunnelBreakdownBy.parse('platform'), FunnelBreakdownBy.platform);
    expect(FunnelBreakdownBy.parse('version'), FunnelBreakdownBy.version);
    expect(FunnelBreakdownBy.parse('param'), FunnelBreakdownBy.param);
    expect(FunnelBreakdownBy.parse('userProp'), FunnelBreakdownBy.userProp);
    expect(() => FunnelBreakdownBy.parse('unknown'), throwsFormatException);

    expect(FunnelBreakdownBy.platform.wire, 'platform');
    expect(FunnelBreakdownBy.version.wire, 'version');
    expect(FunnelBreakdownBy.param.wire, 'param');
    expect(FunnelBreakdownBy.userProp.wire, 'userProp');
  });

  test('FunnelBreakdown validate requirements', () {
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.platform).validate(), isNull);
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.version).validate(), isNull);

    expect(const FunnelBreakdown(by: FunnelBreakdownBy.param).validate(),
        'Breakdown by param requires a parameter key');
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.param, key: 'bad key!').validate(),
        'Invalid parameter key "bad key!"');
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.param, key: 'step_id').validate(), isNull);

    expect(const FunnelBreakdown(by: FunnelBreakdownBy.userProp).validate(),
        'Breakdown by userProp requires a parameter key');
    expect(const FunnelBreakdown(by: FunnelBreakdownBy.userProp, key: 'vip').validate(), isNull);
  });

  test('FunnelBreakdown toJson and fromJson round trip', () {
    const b1 = FunnelBreakdown(by: FunnelBreakdownBy.platform);
    expect(FunnelBreakdown.fromJson(b1.toJson()).by, FunnelBreakdownBy.platform);
    expect(FunnelBreakdown.fromJson(b1.toJson()).key, isNull);

    const b2 = FunnelBreakdown(by: FunnelBreakdownBy.param, key: 'stage');
    final j2 = b2.toJson();
    expect(j2, {'by': 'param', 'key': 'stage'});
    final parsed2 = FunnelBreakdown.fromJson(j2);
    expect(parsed2.by, FunnelBreakdownBy.param);
    expect(parsed2.key, 'stage');
  });

  test('FunnelResult with segments serializes and deserializes', () {
    const seg = FunnelSegmentResult(
      value: 'ANDROID',
      steps: [
        FunnelSegmentStepResult(
          players: 10,
          fromPrevious: null,
          fromFirst: 1.0,
          dropped: null,
          medianSeconds: null,
        ),
        FunnelSegmentStepResult(
          players: 5,
          fromPrevious: 0.5,
          fromFirst: 0.5,
          dropped: 5,
          medianSeconds: 42.0,
        ),
      ],
      totalConversion: 0.5,
    );
    final res = FunnelResult(
      steps: const [
        FunnelStepResult(
          index: 0,
          event: 'start',
          players: 10,
          fromPrevious: null,
          fromFirst: 1.0,
          dropped: null,
          medianSeconds: null,
        ),
      ],
      totalConversion: 0.5,
      biggestDropIndex: 0,
      segments: const [seg],
    );

    final json = res.toJson();
    expect(json['segments'], isNotEmpty);

    final fromJson = FunnelResult.fromJson(json);
    expect(fromJson.segments.length, 1);
    expect(fromJson.segments.first.value, 'ANDROID');
    expect(fromJson.segments.first.steps.length, 2);
    expect(fromJson.segments.first.steps[1].medianSeconds, 42.0);
    expect(fromJson.segments.first.totalConversion, 0.5);
  });
}
