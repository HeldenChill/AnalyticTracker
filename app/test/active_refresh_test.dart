import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/state/refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActiveRequestRegistry & refreshActivePage', () {
    test('registers, replaces and removes reload callbacks', () async {
      final registry = ActiveRequestRegistry();
      final owner = Object();

      var callCount = 0;
      registry.register(
        page: AppPage.overview,
        owner: owner,
        queryKey: 'key1',
        reload: () async {
          callCount++;
          return const RefreshResult();
        },
      );

      final res1 = await registry.reload(AppPage.overview, analyticTab: 0);
      expect(res1.succeeded, isTrue);
      expect(callCount, 1);

      // Replace with new callback for same owner
      registry.register(
        page: AppPage.overview,
        owner: owner,
        queryKey: 'key2',
        reload: () async {
          callCount += 10;
          return const RefreshResult();
        },
      );

      final res2 = await registry.reload(AppPage.overview, analyticTab: 0);
      expect(res2.succeeded, isTrue);
      expect(callCount, 11);

      // Remove owner
      registry.remove(owner);
      final res3 = await registry.reload(AppPage.overview, analyticTab: 0);
      expect(res3.succeeded, isFalse);
      expect(res3.errors.first, isA<StateError>());
    });

    test('reloads only matching Analytic tab', () async {
      final registry = ActiveRequestRegistry();
      var tab0Calls = 0;
      var tab1Calls = 0;

      registry.register(
        page: AppPage.analytic,
        owner: 'tab0',
        queryKey: 'q0',
        analyticTab: 0,
        reload: () async {
          tab0Calls++;
          return const RefreshResult();
        },
      );

      registry.register(
        page: AppPage.analytic,
        owner: 'tab1',
        queryKey: 'q1',
        analyticTab: 1,
        reload: () async {
          tab1Calls++;
          return const RefreshResult();
        },
      );

      await registry.reload(AppPage.analytic, analyticTab: 1);
      expect(tab0Calls, 0);
      expect(tab1Calls, 1);

      await registry.reload(AppPage.analytic, analyticTab: 0);
      expect(tab0Calls, 1);
      expect(tab1Calls, 1);
    });

    test('aggregates errors and warnings from multiple registrations', () async {
      final registry = ActiveRequestRegistry();
      registry.register(
        page: AppPage.analytic,
        owner: 'part1',
        queryKey: 'k1',
        analyticTab: 3,
        reload: () async => const RefreshResult(warnings: ['warning 1']),
      );

      registry.register(
        page: AppPage.analytic,
        owner: 'part2',
        queryKey: 'k2',
        analyticTab: 3,
        reload: () async => RefreshResult(errors: [Exception('error 2')]),
      );

      final result = await registry.reload(AppPage.analytic, analyticTab: 3);
      expect(result.succeeded, isFalse);
      expect(result.warnings, ['warning 1']);
      expect(result.errors.length, 1);
    });

    testWidgets('ActiveRequestScope registers and unregisters on widget dispose', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var reloadCalls = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ActiveRequestScope(
              page: AppPage.overview,
              queryKey: 'query',
              reload: () async {
                reloadCalls++;
                return const RefreshResult();
              },
              child: const Text('Child Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final registry = container.read(activeRequestRegistryProvider);
      final res = await registry.reload(AppPage.overview, analyticTab: 0);
      expect(res.succeeded, isTrue);
      expect(reloadCalls, 1);

      // Unmount
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      final resAfterUnmount = await registry.reload(AppPage.overview, analyticTab: 0);
      expect(resAfterUnmount.succeeded, isFalse);
    });
  });
}
