import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/widgets/error_retry.dart';
import 'package:analytic_app/src/widgets/studio_async_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('same-query failure retains data and shows error', (t) async {
    final state = ValueNotifier<AsyncValue<int>>(const AsyncData(7));
    addTearDown(state.dispose);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<AsyncValue<int>>(
          valueListenable: state,
          builder: (_, value, __) => StudioAsyncPanel<int>(
            queryKey: 'A',
            value: value,
            onRetry: () {},
            builder: (n) => Text('Measured $n'),
          ),
        ),
      ),
    ));
    state.value = AsyncError(StateError('refresh failed'), StackTrace.empty);
    await t.pumpAndSettle();
    expect(find.text('Measured 7'), findsOneWidget);
    expect(find.textContaining('refresh failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('previous server data in Riverpod wrappers never seeds new query', (t) async {
    final key = ValueNotifier<Object>(('server1', 'filterA'));
    final value = ValueNotifier<AsyncValue<int>>(const AsyncData(7));
    addTearDown(key.dispose);
    addTearDown(value.dispose);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<Object>(
          valueListenable: key,
          builder: (_, k, __) => ValueListenableBuilder<AsyncValue<int>>(
            valueListenable: value,
            builder: (_, v, __) => StudioAsyncPanel<int>(
              queryKey: k,
              value: v,
              onRetry: () {},
              builder: (n) => Text('Measured $n'),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Measured 7'), findsOneWidget);

    key.value = ('server2', 'filterA');
    value.value = const AsyncLoading<int>().copyWithPrevious(
      const AsyncData<int>(7),
      isRefresh: false,
    );
    await t.pump();
    expect(find.text('Measured 7'), findsNothing);

    value.value = AsyncError<int>(StateError('new server failed'), StackTrace.empty)
        .copyWithPrevious(const AsyncData<int>(7));
    await t.pump();
    expect(find.text('Measured 7'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    value.value = const AsyncData(8);
    await t.pump();
    expect(find.text('Measured 8'), findsOneWidget);

    key.value = ('server2', 'filterB');
    value.value = const AsyncLoading<int>().copyWithPrevious(const AsyncData(8));
    await t.pump();
    expect(find.text('Measured 8'), findsNothing);
  });

  testWidgets('same-key loading and error preserve local cache and update indicator', (t) async {
    final state = ValueNotifier<AsyncValue<int>>(const AsyncData(7));
    addTearDown(state.dispose);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<AsyncValue<int>>(
          valueListenable: state,
          builder: (_, value, __) => StudioAsyncPanel<int>(
            queryKey: 'sameKey',
            value: value,
            onRetry: () {},
            builder: (n) => Text('Measured $n'),
          ),
        ),
      ),
    ));
    expect(find.text('Measured 7'), findsOneWidget);

    state.value = const AsyncLoading<int>().copyWithPrevious(const AsyncData(7));
    await t.pump();
    expect(find.text('Measured 7'), findsOneWidget);
    expect(find.text('Updating'), findsOneWidget);

    state.value = AsyncError<int>(StateError('temporary failure'), StackTrace.empty)
        .copyWithPrevious(const AsyncData(7));
    await t.pumpAndSettle();
    expect(find.text('Measured 7'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('temporary failure'), findsOneWidget);

    state.value = const AsyncData(8);
    await t.pumpAndSettle();
    expect(find.text('Measured 8'), findsOneWidget);
    expect(find.text('Measured 7'), findsNothing);
  });

  testWidgets('nullable T accepts AsyncData(null)', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StudioAsyncPanel<int?>(
          queryKey: 'nullKey',
          value: const AsyncData(null),
          onRetry: () {},
          builder: (n) => Text('Value is $n'),
        ),
      ),
    ));
    expect(find.text('Value is null'), findsOneWidget);
  });

  testWidgets('ErrorRetry displays 404 guidance and fires callback', (t) async {
    var retried = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorRetry(
          error: ApiException('Not Found', statusCode: 404, path: 'analysis/survival'),
          onRetry: () => retried = true,
        ),
      ),
    ));
    expect(find.textContaining('Not Found'), findsOneWidget);
    expect(
      find.textContaining('This endpoint is unavailable. Restart the server with the current project version.'),
      findsOneWidget,
    );
    await t.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('ErrorRetry for normal StateError omits 404 guidance', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorRetry(
          error: StateError('something crashed'),
          onRetry: () {},
        ),
      ),
    ));
    expect(find.textContaining('something crashed'), findsOneWidget);
    expect(
      find.textContaining('This endpoint is unavailable'),
      findsNothing,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}
