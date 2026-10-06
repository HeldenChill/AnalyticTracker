import 'package:analytic_app/src/state/filters.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer make() {
    final c = ProviderContainer(overrides: [
      filtersProvider.overrideWith(() => FiltersNotifier(() => DateTime(2026, 10, 6, 15, 30))),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('default is last 30 days ending today', () {
    expect(make().read(filtersProvider), const Filters(from: '2026-09-07', to: '2026-10-06'));
  });

  test('preset keeps platform and version', () {
    final c = make();
    final n = c.read(filtersProvider.notifier);
    n.setPlatform('IOS');
    n.setVersion('1.0.0');
    n.applyPreset(7);
    expect(c.read(filtersProvider),
        const Filters(from: '2026-09-30', to: '2026-10-06', platform: 'IOS', version: '1.0.0'));
  });

  test('setRange and clearing platform', () {
    final c = make();
    final n = c.read(filtersProvider.notifier);
    n.setPlatform('IOS');
    n.setRange('2026-08-01', '2026-08-31');
    n.setPlatform(null);
    expect(c.read(filtersProvider), const Filters(from: '2026-08-01', to: '2026-08-31'));
  });

  test('defaultFilters across a month boundary', () {
    expect(defaultFilters(DateTime(2026, 3, 1), days: 2), const Filters(from: '2026-02-28', to: '2026-03-01'));
  });
}
