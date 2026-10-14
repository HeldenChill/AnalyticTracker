import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/state/events_explorer.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/state/refresh.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const filters = Filters(from: '2026-10-01', to: '2026-10-04');

class _Api extends ApiClient {
  _Api() : super('http://review');
  int version = 1;
  @override
  Future<List<EventCount>> counts(String from, String to,
      {String? name, String? platform, String? version, bool includeTest = false}) async =>
      [EventCount(day: from, eventName: 'event', count: this.version)];
  @override
  Future<List<DayStat>> days() async => [
    for (final day in daysBetween(filters.from, filters.to))
      DayStat(day: day, rowCount: version, pulledAt: '2026-10-05T00:00:00Z'),
  ];
}

void main() {
  for (final explicitIdentity in [false, true]) {
  testWidgets('recreated Events scope reloads stale request (explicit identity=$explicitIdentity)', (t) async {
    final api = _Api();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      selectedPageProvider.overrideWith((ref) => AppPage.events),
    ]);
    addTearDown(api.close);
    addTearDown(container.dispose);
    bool show = true;
    late StateSetter change;
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: StatefulBuilder(builder: (context, update) {
        change = update;
        if (!show) return const SizedBox.shrink();
        return Consumer(builder: (context, ref, child) {
          const query = (filters: filters, compare: false);
          final value = ref.watch(eventsExplorerProvider(query));
          return ActiveRequestScope(
            page: AppPage.events,
            queryKey: ('http://review', query),
            cacheKey: explicitIdentity ? ('events', 'http://review', query) : null,
            reload: () async {
              await ref.refresh(eventsExplorerProvider(query).future);
              return const RefreshResult();
            },
            child: Text('count=${value.valueOrNull?.current.first.count}'),
          );
        });
      })),
    ));
    await t.pumpAndSettle();
    expect(find.text('count=1'), findsOneWidget);
    change(() => show = false);
    container.read(selectedPageProvider.notifier).state = AppPage.overview;
    await t.pumpAndSettle();
    final registry = container.read(activeRequestRegistryProvider);
    registry.register(page: AppPage.overview, owner: Object(), queryKey: 'overview',
        reload: () async => const RefreshResult());
    api.version = 2;
    await registry.reload(AppPage.overview, analyticTab: 0);
    container.read(selectedPageProvider.notifier).state = AppPage.events;
    change(() => show = true);
    await t.pumpAndSettle();
    expect(find.text('count=2'), findsOneWidget,
        reason: 'same cached request must retain freshness across scope recreation');
  });
  }
}
