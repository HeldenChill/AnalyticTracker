import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last [days] local calendar days ending on [now]'s date.
Filters defaultFilters(DateTime now, {int days = 30}) => Filters(
      from: formatDay(DateTime(now.year, now.month, now.day - (days - 1))),
      to: formatDay(DateTime(now.year, now.month, now.day)),
    );

class FiltersNotifier extends Notifier<Filters> {
  FiltersNotifier([this._clock]);
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)();

  @override
  Filters build() => defaultFilters(_now());

  void setRange(String from, String to) => state = state.withRange(from, to);

  void applyPreset(int days) {
    final d = defaultFilters(_now(), days: days);
    state = state.withRange(d.from, d.to);
  }

  void setPlatform(String? p) => state = state.withPlatform(p);

  void setVersion(String? v) => state = state.withVersion(v);
}

final filtersProvider = NotifierProvider<FiltersNotifier, Filters>(FiltersNotifier.new);
