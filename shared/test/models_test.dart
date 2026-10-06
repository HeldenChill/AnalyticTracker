import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  test('DayStat round trip', () {
    const d = DayStat(day: '2026-10-01', rowCount: 3, pulledAt: '2026-10-02T01:00:00.000Z');
    expect(DayStat.fromJson(d.toJson()).toJson(), d.toJson());
    expect(d.toJson(), {'day': '2026-10-01', 'rowCount': 3, 'pulledAt': '2026-10-02T01:00:00.000Z'});
  });
  test('EventCount round trip', () {
    const c = EventCount(day: '2026-10-01', eventName: 'stg_start', count: 5);
    expect(EventCount.fromJson(c.toJson()).toJson(), {'day': '2026-10-01', 'eventName': 'stg_start', 'count': 5});
  });
  test('ParamBucket round trip', () {
    const b = ParamBucket(value: '1', count: 2);
    expect(ParamBucket.fromJson(b.toJson()).toJson(), {'value': '1', 'count': 2});
  });
  test('FunnelStep round trip', () {
    const f = FunnelStep(eventName: 'stg_cmp', users: 7);
    expect(FunnelStep.fromJson(f.toJson()).toJson(), {'eventName': 'stg_cmp', 'users': 7});
  });
}
