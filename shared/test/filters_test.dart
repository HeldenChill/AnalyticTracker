import 'package:analytic_shared/analytic_shared.dart';
import 'package:test/test.dart';

void main() {
  const f = Filters(from: '2026-10-01', to: '2026-10-07');

  test('lengthDays is inclusive', () {
    expect(f.lengthDays, 7);
    expect(const Filters(from: '2026-10-01', to: '2026-10-01').lengthDays, 1);
  });

  test('previousPeriod is the same length immediately before', () {
    final p = f.withPlatform('IOS').previousPeriod();
    expect(p.from, '2026-09-24');
    expect(p.to, '2026-09-30');
    expect(p.platform, 'IOS');
  });

  test('toQuery omits null filters', () {
    expect(f.toQuery(), {'from': '2026-10-01', 'to': '2026-10-07'});
    expect(f.withPlatform('ANDROID').withVersion('1.2.0').toQuery(),
        {'from': '2026-10-01', 'to': '2026-10-07', 'platform': 'ANDROID', 'version': '1.2.0'});
  });

  test('Filters equality is by value', () {
    expect(f.withPlatform('IOS'), const Filters(from: '2026-10-01', to: '2026-10-07', platform: 'IOS'));
    expect(f.withPlatform('IOS').hashCode,
        const Filters(from: '2026-10-01', to: '2026-10-07', platform: 'IOS').hashCode);
    expect(f == f.withVersion('1.0.0'), isFalse);
    expect(f.withPlatform('IOS').withPlatform(null), f);
  });

  test('withRange keeps platform and version', () {
    final g = f.withPlatform('IOS').withVersion('1.0').withRange('2026-01-01', '2026-01-02');
    expect(g, const Filters(from: '2026-01-01', to: '2026-01-02', platform: 'IOS', version: '1.0'));
  });
}
