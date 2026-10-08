import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

export 'state/filters.dart' show filtersProvider, FiltersNotifier, defaultFilters;

const defaultBaseUrl = 'http://localhost:8080';
const baseUrlPrefKey = 'baseUrl';

class BaseUrlNotifier extends Notifier<String> {
  BaseUrlNotifier(this._initial);
  final String _initial;

  @override
  String build() => _initial;

  void set(String value) => state = value;
}

final baseUrlProvider =
    NotifierProvider<BaseUrlNotifier, String>(() => BaseUrlNotifier(defaultBaseUrl));

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(baseUrlProvider));
  ref.onDispose(client.close);
  return client;
});

final daysProvider = FutureProvider<List<DayStat>>((ref) => ref.watch(apiClientProvider).days());

final eventNamesProvider =
    FutureProvider<List<String>>((ref) => ref.watch(apiClientProvider).eventNames());

final filterOptionsProvider =
    FutureProvider<FilterOptions>((ref) => ref.watch(apiClientProvider).filterOptions());

final overviewProvider = FutureProvider.family<OverviewData, Filters>(
    (ref, f) => ref.watch(apiClientProvider).overview(f));

final retentionProvider = FutureProvider.family<RetentionData, Filters>(
    (ref, f) => ref.watch(apiClientProvider).retention(f));

final progressionProvider = FutureProvider.family<ProgressionData, Filters>(
    (ref, f) => ref.watch(apiClientProvider).progression(f));

final countsProvider = FutureProvider.family<List<EventCount>, ({Filters filters, String? name})>(
    (ref, q) => ref.watch(apiClientProvider).counts(q.filters.from, q.filters.to,
        name: q.name, platform: q.filters.platform, version: q.filters.version, includeTest: q.filters.includeTest));

final paramProvider =
    FutureProvider.family<List<ParamBucket>, ({Filters filters, String name, String key})>(
        (ref, q) => ref.watch(apiClientProvider).param(q.name, q.key, q.filters.from, q.filters.to,
            platform: q.filters.platform, version: q.filters.version, includeTest: q.filters.includeTest));


final savedFunnelsProvider =
    FutureProvider<List<SavedFunnel>>((ref) => ref.watch(apiClientProvider).funnels());

final funnelBreakdownProvider = StateProvider.autoDispose<FunnelBreakdown?>((ref) => null);

final userPropKeysProvider = FutureProvider.autoDispose.family<List<String>, Filters>((ref, f) =>
    ref.watch(apiClientProvider).userPropKeys(f.from, f.to,
        platform: f.platform, version: f.version, includeTest: f.includeTest));

final funnelIntervalProvider = StateProvider.autoDispose<FunnelInterval>((ref) => FunnelInterval.day);

final funnelResultProvider = FutureProvider.autoDispose
    .family<FunnelResult, ({FunnelDef def, Filters filters, FunnelBreakdown? breakdown, FunnelInterval? interval})>(
        (ref, q) => ref.watch(apiClientProvider).runFunnel(q.def, q.filters,
            breakdown: q.breakdown, interval: q.interval));

final paramKeysProvider = FutureProvider.family<List<String>, ({String event, Filters filters})>(
    (ref, q) => ref.watch(apiClientProvider).paramKeys(q.event, q.filters));

/// Seen values of one event parameter with counts, most frequent first (server keeps the top 50).
final paramValuesProvider =
    FutureProvider.family<List<ParamBucket>, ({String event, String key, Filters filters})>((ref, q) async {
  final buckets = await ref.watch(apiClientProvider).param(q.event, q.key, q.filters.from, q.filters.to,
      platform: q.filters.platform, version: q.filters.version, includeTest: q.filters.includeTest);
  return [for (final b in buckets) if (b.value != '(none)') b];
});

final funnelPlayersProvider = FutureProvider.autoDispose.family<FunnelPlayersResult, ({
  FunnelDef def,
  Filters filters,
  int step,
  FunnelPlayerOutcome outcome,
  FunnelBreakdown? breakdown,
  String? segment,
  int? limit,
})>((ref, q) => ref.watch(apiClientProvider).funnelPlayers(
  q.def,
  q.filters,
  step: q.step,
  outcome: q.outcome,
  breakdown: q.breakdown,
  segment: q.segment,
  limit: q.limit ?? 100,
));

final playerEventsProvider = FutureProvider.autoDispose.family<List<PlayerTimelineEvent>, ({
  String uid,
  int fromTs,
  int toTs,
  bool includeTest,
  int? limit,
})>((ref, q) => ref.watch(apiClientProvider).playerEvents(
  q.uid,
  fromTs: q.fromTs,
  toTs: q.toTs,
  includeTest: q.includeTest,
  limit: q.limit ?? 300,
));

