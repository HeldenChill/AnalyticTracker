import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

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

final countsProvider =
    FutureProvider.family<List<EventCount>, ({String from, String to, String? name})>(
        (ref, q) => ref.watch(apiClientProvider).counts(q.from, q.to, name: q.name));

final paramProvider =
    FutureProvider.family<List<ParamBucket>, ({String name, String key, String from, String to})>(
        (ref, q) => ref.watch(apiClientProvider).param(q.name, q.key, q.from, q.to));

/// `steps` is comma-joined on purpose: records holding a List never compare equal.
final funnelProvider =
    FutureProvider.family<List<FunnelStep>, ({String steps, String from, String to})>(
        (ref, q) => ref.watch(apiClientProvider).funnel(q.steps, q.from, q.to));
