import 'package:analytic_app/src/widgets/studio_async_panel.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy impossible date is unknown rather than normalized', () {
    expect(DateTime.tryParse('2026-02-30T01:00:00Z'), isNull);
  });
  testWidgets('changing display range during failed global refresh retains rows', (t) async {
    const rows = [DayStat(day: '2026-10-01', rowCount: 12, pulledAt: 'a'),
      DayStat(day: '2026-10-03', rowCount: 3, pulledAt: 'b')];
    final range = ValueNotifier<Filters>(const Filters(from: '2026-10-01', to: '2026-10-03'));
    final value = ValueNotifier<AsyncValue<List<DayStat>>>(const AsyncData(rows));
    addTearDown(range.dispose); addTearDown(value.dispose);
    await t.pumpWidget(MaterialApp(home: Scaffold(body:
      ValueListenableBuilder<Filters>(valueListenable: range, builder: (_, f, __) =>
        ValueListenableBuilder<AsyncValue<List<DayStat>>>(valueListenable: value,
          builder: (_, v, __) => StudioAsyncPanel<List<DayStat>>(
            queryKey: ('same-server', f.from, f.to), value: v, onRetry: () {},
            builder: (days) => Text('Events ${days.where((d) => d.day.compareTo(f.from) >= 0 && d.day.compareTo(f.to) <= 0).fold<int>(0, (n, d) => n + d.rowCount)}'),
          ))))));
    expect(find.text('Events 15'), findsOneWidget);
    value.value = const AsyncLoading<List<DayStat>>().copyWithPrevious(const AsyncData(rows));
    await t.pump();
    range.value = const Filters(from: '2026-10-02', to: '2026-10-03');
    value.value = AsyncError<List<DayStat>>(StateError('refresh failed'), StackTrace.empty)
      .copyWithPrevious(const AsyncData(rows));
    await t.pump();
    expect(find.text('Events 3'), findsOneWidget);
  });
}
