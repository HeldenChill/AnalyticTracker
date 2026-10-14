import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:analytic_app/src/screens/counts_screen.dart';
import 'package:analytic_app/src/state/events_explorer.dart';
import 'package:analytic_app/src/widgets/funnel_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/screens/param_screen.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_app/src/state/event_vocabulary.dart';
import 'package:analytic_app/src/widgets/charts/chart_motion.dart';
import 'package:analytic_app/src/widgets/charts/ranked_bar_chart.dart';
import 'package:analytic_app/src/widgets/event_picker.dart';
import 'package:analytic_app/src/widgets/vocabulary_scope.dart';
import 'package:analytic_app/src/presentation/event_catalog_import.dart';
import 'event_catalog_import_test.dart' show csvFile;
import 'event_vocabulary_state_test.dart' show MemoryVocabularyRepository;

class _FixedLanguageFilters extends FiltersNotifier {
  _FixedLanguageFilters(this.initial);
  final Filters initial;
  @override
  Filters build() => initial;
}

void main() {
  testWidgets(
      'real CSV batch and incremental import relabel retained Events and Funnel without merging counts',
      (t) async {
    t.view.physicalSize = const Size(1440, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final requests = <Uri>[];
    const filters = Filters(
        from: '2026-10-01',
        to: '2026-10-04',
        platform: 'IOS',
        version: '2.0',
        includeTest: true);
    final client = ApiClient('http://fixture', client: MockClient((r) async {
      requests.add(r.url);
      Object payload;
      if (r.url.path == '/days') {
        payload = [
          for (final day in [
            '2026-10-01',
            '2026-10-02',
            '2026-10-03',
            '2026-10-04'
          ])
            DayStat(day: day, rowCount: 10, pulledAt: '2026-10-05T00:00:00Z')
                .toJson()
        ];
      } else if (r.url.path == '/events/count') {
        payload = r.url.queryParameters['from'] == '2026-10-01'
            ? [
                const EventCount(
                        day: '2026-10-01', eventName: 'sup_buy', count: 7)
                    .toJson(),
                const EventCount(
                        day: '2026-10-01',
                        eventName: 'custom_support',
                        count: 3)
                    .toJson()
              ]
            : <dynamic>[];
      } else {
        payload = <dynamic>[];
      }
      return http.Response(jsonEncode(payload), 200);
    }));
    addTearDown(client.close);
    final repo = MemoryVocabularyRepository(),
        c = ProviderContainer(overrides: [
          apiClientProvider.overrideWithValue(client),
          filtersProvider.overrideWith(() => _FixedLanguageFilters(filters)),
          vocabularyRepositoryProvider.overrideWithValue(repo)
        ]);
    addTearDown(c.dispose);
    final scope = c.read(currentVocabularyScopeProvider),
        controller = c.read(vocabularyProvider(scope).notifier);
    await controller.loaded;
    final sourceFiles = Directory('../csv')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.csv'))
        .map((f) => VocabularyFile(
            f.uri.pathSegments.last, Uint8List.fromList(f.readAsBytesSync())))
        .toList();
    expect(
        await controller.apply(previewVocabulary(
            files: sourceFiles,
            current: c.read(effectiveVocabularyProvider),
            scope: scope,
            baseRevision: 0)),
        ApplyResult.applied);
    const funnel = FunnelResult(steps: [
      FunnelStepResult(
          index: 0,
          event: 'sup_buy',
          players: 7,
          fromPrevious: null,
          fromFirst: 1,
          dropped: null,
          medianSeconds: null)
    ], totalConversion: 1, biggestDropIndex: null);
    final active = StateProvider<int>((ref) => 0);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            home: Scaffold(
                body: VocabularyHost(
                    child: Consumer(
                        builder: (context, ref, _) => IndexedStack(
                                index: ref.watch(active),
                                children: [
                                  CountsScreen(),
                                  const FunnelChart(result: funnel)
                                ])))))));
    await t.pumpAndSettle();
    final before = requests.length;
    final replacement = previewVocabulary(
        files: [
          csvFile('delta.csv',
              'Event,Abbreviated Event,Display Name\nsupport_buy,sup_buy,Support activity\ncustom_support,custom_support,Support activity')
        ],
        current: c.read(effectiveVocabularyProvider),
        scope: scope,
        baseRevision: 1);
    expect(await controller.apply(replacement), ApplyResult.applied);
    await t.pumpAndSettle();
    final data = c
        .read(eventsExplorerProvider((filters: filters, compare: true)))
        .requireValue
        .current;
    expect(data.map((e) => e.count).toList(), [7, 3]);
    expect(
        data.map((e) => e.eventName).toList(), ['sup_buy', 'custom_support']);
    expect(find.text('Support activity'), findsWidgets);
    await Scrollable.ensureVisible(
        t.element(find.byKey(const ValueKey('events-search'))));
    await t.pumpAndSettle();
    await t.enterText(
        find.byKey(const ValueKey('events-search')), 'support_buy');
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-row-sup_buy')), findsWidgets);
    expect(
        find.byKey(const ValueKey('event-row-custom_support')), findsNothing);
    c.read(active.notifier).state = 1;
    await t.pumpAndSettle();
    expect(find.text('1. Support activity'), findsOneWidget);
    c.read(active.notifier).state = 0;
    await t.pumpAndSettle();
    expect(requests.length, before);
    expect(
        requests
            .where((r) =>
                r.path == '/events/count' &&
                r.queryParameters['from'] == '2026-10-01')
            .single
            .queryParameters,
        {
          'from': '2026-10-01',
          'to': '2026-10-04',
          'platform': 'IOS',
          'version': '2.0',
          'test': '1'
        });
    final fresh = ProviderContainer(
        overrides: [vocabularyRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(fresh.dispose);
    await fresh.read(vocabularyProvider(scope).notifier).loaded;
    expect(fresh.read(effectiveVocabularyProvider).eventLabel('sup_buy'),
        'Support activity');
    expect(
        fresh
            .read(effectiveVocabularyProvider)
            .meaning('tut')!
            .tutorials
            .length,
        24);
  });
  testWidgets(
      'parameter labels update without raw request or selection changes',
      (t) async {
    final requests = <Uri>[];
    final client = ApiClient('http://fixture', client: MockClient((r) async {
      requests.add(r.url);
      final payload = switch (r.url.path) {
        '/events/names' => ['sup_buy'],
        '/events/param-keys' => ['stg'],
        '/events/param' => [
            {'value': '3', 'count': 7}
          ],
        _ => <dynamic>[]
      };
      return http.Response(jsonEncode(payload), 200);
    }));
    addTearDown(client.close);
    final c = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
      vocabularyRepositoryProvider
          .overrideWithValue(MemoryVocabularyRepository()),
      parameterEventProvider.overrideWith((ref) => 'sup_buy'),
      parameterKeyProvider.overrideWith((ref) => 'stg')
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
            home: Scaffold(body: VocabularyHost(child: ParamScreen())))));
    await t.pumpAndSettle();
    expect(find.text('Support item purchased'), findsWidgets);
    expect(find.text('Stage'), findsWidgets);
    final query =
        requests.singleWhere((r) => r.path == '/events/param').queryParameters;
    expect(query['name'], 'sup_buy');
    expect(query['key'], 'stg');
    final count = requests.length,
        scope = c.read(currentVocabularyScopeProvider);
    await c.read(vocabularyProvider(scope).notifier).loaded;
    final p = previewVocabulary(
        files: [
          csvFile('names.csv',
              'Event,Abbreviated Event,Display Name\nsupport_buy,sup_buy,Support bought\nreward,new_rwd,Reward')
        ],
        current: c.read(effectiveVocabularyProvider),
        scope: scope,
        baseRevision: 0);
    expect(await c.read(vocabularyProvider(scope).notifier).apply(p),
        ApplyResult.applied);
    await t.pumpAndSettle();
    expect(find.text('Support bought'), findsWidgets);
    expect(requests.length, count);
    expect(c.read(parameterEventProvider), 'sup_buy');
    expect(c.read(parameterKeyProvider), 'stg');
    await t.tap(find.byType(DropdownButton<String?>));
    await t.pumpAndSettle();
    expect(find.text('Reward'), findsNothing);
    final p2 = previewVocabulary(
        files: [
          csvFile('n.csv',
              'Event,Abbreviated Event,Display Name\nsupport_buy,sup_buy,New name')
        ],
        current: c.read(effectiveVocabularyProvider),
        scope: scope,
        baseRevision: 1);
    await c.read(vocabularyProvider(scope).notifier).apply(p2);
    await t.pumpAndSettle();
    expect(find.byType(EventPicker), findsOneWidget);
    expect(find.text('New name'), findsWidgets);
    expect(requests.length, count);
  });
  testWidgets('rank labels change without replay but value changes animate',
      (t) async {
    Widget host(String label, double value) => MaterialApp(
        home: Scaffold(
            body: RankedBarChart(
                unit: 'events',
                values: [RankedValue('sup_buy', label, value)])));
    await t.pumpWidget(host('Old', 7));
    await t.pumpAndSettle();
    await t.pumpWidget(host('New', 7));
    await t.pump(const Duration(milliseconds: 100));
    final builder = find
        .descendant(
            of: find.byType(ChartMotion), matching: find.byType(Builder))
        .first;
    expect(ChartMotion.of(t.element(builder)).running, isFalse);
    expect(find.text('New'), findsWidgets);
    await t.pumpWidget(host('New', 9));
    await t.pump(const Duration(milliseconds: 50));
    expect(ChartMotion.of(t.element(builder)).running, isTrue);
    await t.pumpAndSettle();
  });
  testWidgets('one-sheet import keeps FTU and tutorial meanings; picker stays server-driven',
      (t) async {
    final repo = MemoryVocabularyRepository();
    final c = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(ApiClient('http://fixture',
          client: MockClient((r) async => http.Response(
              jsonEncode(r.url.path == '/events/names' ? ['sup_buy'] : []),
              200)))),
      vocabularyRepositoryProvider.overrideWithValue(repo)
    ]);
    addTearDown(c.dispose);
    final scope = c.read(currentVocabularyScopeProvider),
        controller = c.read(vocabularyProvider(scope).notifier);
    await controller.loaded;
    final ftu = c.read(effectiveVocabularyProvider).eventLabel('ftu_stg_start');
    expect(
        await controller.apply(previewVocabulary(
            files: [
              csvFile('one.csv',
                  'Event,Abbreviated Event,Display Name,Description\nsupport_buy,sup_buy,Support item bought,A player buys support during a stage.\nnew_reward,new_rwd,New reward collected,A player collects the new reward.')
            ],
            current: c.read(effectiveVocabularyProvider),
            scope: scope,
            baseRevision: 0)),
        ApplyResult.applied);
    final v = c.read(effectiveVocabularyProvider);
    expect(v.eventLabel('sup_buy'), 'Support item bought');
    expect(v.eventLabel('new_rwd'), 'New reward collected');
    expect(v.eventLabel('ftu_stg_start'), ftu);
    expect(v.meaning('tut')!.tutorials.length, 24);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            home: Scaffold(
                body: VocabularyHost(
                    child: EventPicker(value: null, onChanged: (_) {}))))));
    await t.pumpAndSettle();
    await t.tap(find.byType(EventPicker));
    await t.pumpAndSettle();
    expect(find.text('Support item bought'), findsWidgets);
    expect(find.text('New reward collected'), findsNothing);
  });
}
