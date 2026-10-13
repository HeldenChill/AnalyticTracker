import 'dart:async';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/shell/page_stage.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/state/refresh.dart';
import 'package:analytic_shared/analytic_shared.dart';
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

    test('exact freshness test with deferred hidden reload', () async {
      final registry = ActiveRequestRegistry();
      final active = Object(), hidden = Object();
      var a = 0, b = 0;
      registry.register(
        page: AppPage.overview,
        owner: active,
        queryKey: 'a',
        reload: () async {
          a++;
          return const RefreshResult();
        },
      );
      registry.register(
        page: AppPage.retention,
        owner: hidden,
        queryKey: 'b',
        reload: () async {
          b++;
          return const RefreshResult();
        },
      );
      await registry.reload(AppPage.overview, analyticTab: 0);
      expect(a, 1);
      expect(b, 0);
      await registry.reloadOwnerIfStale(hidden);
      expect(b, 1);
      await registry.reloadOwnerIfStale(hidden);
      expect(b, 1);
    });

    test('start stale owner reload for key old, re-register key new, finishes old, calls new', () async {
      final registry = ActiveRequestRegistry();
      final owner = Object();
      final completerOld = Completer<RefreshResult>();
      var oldCalls = 0;
      var newCalls = 0;

      registry.register(
        page: AppPage.retention,
        owner: owner,
        queryKey: 'old',
        reload: () async {
          oldCalls++;
          return await completerOld.future;
        },
      );

      await registry.reload(AppPage.overview, analyticTab: 0);

      final staleFuture = registry.reloadOwnerIfStale(owner);
      expect(oldCalls, 1);

      registry.register(
        page: AppPage.retention,
        owner: owner,
        queryKey: 'new',
        reload: () async {
          newCalls++;
          return const RefreshResult();
        },
      );

      completerOld.complete(const RefreshResult());
      final oldResult = await staleFuture;
      expect(oldResult.superseded, isTrue);

      await registry.reloadOwnerIfStale(owner);
      expect(newCalls, 1);
    });

    test('same-key concurrent calls coalesce into single ticket', () async {
      final registry = ActiveRequestRegistry();
      final owner = Object();
      final completer = Completer<RefreshResult>();
      var calls = 0;

      registry.register(
        page: AppPage.retention,
        owner: owner,
        queryKey: 'k',
        reload: () async {
          calls++;
          return await completer.future;
        },
      );

      await registry.reload(AppPage.overview, analyticTab: 0);

      final f1 = registry.reloadOwnerIfStale(owner);
      final f2 = registry.reloadOwnerIfStale(owner);
      expect(calls, 1);

      completer.complete(const RefreshResult());
      final r1 = await f1;
      final r2 = await f2;
      expect(r1.succeeded, isTrue);
      expect(r2.succeeded, isTrue);
      expect(calls, 1);
    });

    test('failure retry leaves stale state, warning-only marks fresh', () async {
      final registry = ActiveRequestRegistry();
      final owner = Object();
      var calls = 0;
      var shouldFail = true;

      registry.register(
        page: AppPage.retention,
        owner: owner,
        queryKey: 'k',
        reload: () async {
          calls++;
          if (shouldFail) {
            return RefreshResult(errors: [Exception('fail')]);
          }
          return const RefreshResult(warnings: ['warning']);
        },
      );

      await registry.reload(AppPage.overview, analyticTab: 0);

      final failResult = await registry.reloadOwnerIfStale(owner);
      expect(failResult.errors.isNotEmpty, isTrue);
      expect(calls, 1);

      shouldFail = false;
      final warnResult = await registry.reloadOwnerIfStale(owner);
      expect(warnResult.warnings, isNotEmpty);
      expect(calls, 2);

      await registry.reloadOwnerIfStale(owner);
      expect(calls, 2);
    });

    test('midflight disposal does not crash or reinsert owner', () async {
      final registry = ActiveRequestRegistry();
      final owner = Object();
      final completer = Completer<RefreshResult>();

      registry.register(
        page: AppPage.overview,
        owner: owner,
        queryKey: 'k',
        reload: () => completer.future,
      );

      final reloadFuture = registry.reload(AppPage.overview, analyticTab: 0);
      registry.dispose();
      completer.complete(const RefreshResult());
      final res = await reloadFuture;
      expect(res.superseded, isTrue);
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

    testWidgets('refresh does not refetch retained hidden page', (tester) async {
      int hiddenCalls = 0;
      const f = Filters(from: '2026-10-01', to: '2026-10-04');
      late WidgetRef shellRef;

      Future<void> render(int index) async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            overviewProvider(f).overrideWith((ref) async => const OverviewData(
              kpis: Kpis(dau: 10, newUsers: 0, sessions: 0, sessionsPerDau: 0, playtimeMinPerDau: 0, uninstalls: 0),
              previous: null,
              daily: [],
            )),
            retentionProvider(f).overrideWith((ref) async {
              hiddenCalls++;
              return const RetentionData(
                offsets: [],
                lastDataDay: null,
                cohorts: [],
                average: [],
              );
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(builder: (context, ref, child) {
                shellRef = ref;
                return PageStage(
                  index: index,
                  pages: [
                    Consumer(builder: (context, ref, child) {
                      ref.watch(overviewProvider(f));
                      return ActiveRequestScope(
                        page: AppPage.overview,
                        queryKey: f,
                        reload: () async {
                          await Future.wait([ref.refresh(overviewProvider(f).future)]);
                          return const RefreshResult();
                        },
                        child: const Text('overview'),
                      );
                    }),
                    Consumer(builder: (context, ref, child) {
                      ref.watch(retentionProvider(f));
                      return const Text('retention');
                    }),
                  ],
                );
              }),
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }

      await render(0);
      await render(1);
      await render(0);
      final before = hiddenCalls;
      await refreshActivePage(shellRef, AppPage.overview, analyticTab: 0);
      await tester.pumpAndSettle();
      expect(hiddenCalls, before, reason: 'hidden retention must not fetch on Overview refresh');
    });
  });
}

