import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/state/refresh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distinct Survival endpoints must retain distinct freshness after one fails', () async {
    final registry = ActiveRequestRegistry();
    final survival = Object(), impact = Object();
    var impactCalls = 0;
    const query = ('http://server', 'same filters', 'version');
    registry.register(
      page: AppPage.analytic,
      analyticTab: 3,
      owner: survival,
      queryKey: query,
      cacheKey: ('survival', query),
      reload: () async => const RefreshResult(),
    );
    registry.register(
      page: AppPage.analytic,
      analyticTab: 3,
      owner: impact,
      queryKey: query,
      cacheKey: ('versionImpact', query),
      reload: () async {
        impactCalls++;
        return RefreshResult(errors: [StateError('versionImpact request failed')]);
      },
    );
    final result = await registry.reload(AppPage.analytic, analyticTab: 3);
    expect(result.errors, hasLength(1));
    await registry.reloadOwnerIfStale(impact);
    expect(
      impactCalls,
      2,
      reason: 'successful survival must not mark failed versionImpact request fresh',
    );
  });
}
