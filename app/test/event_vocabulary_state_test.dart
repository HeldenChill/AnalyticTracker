import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/presentation/event_catalog_import.dart';
import 'package:analytic_app/src/state/event_vocabulary.dart';
import 'package:analytic_app/src/state/event_vocabulary_repository.dart';
import 'event_catalog_import_test.dart' show csvFile;

class MemoryVocabularyRepository implements VocabularyRepository {
  final data = <String, String>{};
  Completer<bool>? gate;
  bool fail = false;
  int writes = 0;
  @override
  Future<String?> read(String scope) async => data[scope];
  @override
  Future<bool> write(String scope, String value) async {
    writes++;
    final ok = gate == null ? !fail : await gate!.future;
    if (ok) data[scope] = value;
    return ok;
  }
}

void main() {
  test('scope normalization retains distinct sources and base paths', () {
    expect(vocabularyScope('HTTP://LOCALHOST:80/'),
        vocabularyScope('http://localhost'));
    expect(vocabularyScope('http://localhost/api/'),
        vocabularyScope('http://localhost/api'));
    expect(vocabularyScope('http://localhost'),
        isNot(vocabularyScope('http://127.0.0.1')));
    expect(vocabularyScope('http://localhost?a=1'),
        isNot(vocabularyScope('http://localhost?a=2')));
  });
  for (final fail in [false, true]) {
    test('durable save publishes only on success fail=$fail', () async {
      final repo = MemoryVocabularyRepository()..fail = fail;
      final c = ProviderContainer(
          overrides: [vocabularyRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      final scope = c.read(currentVocabularyScopeProvider),
          provider = vocabularyProvider(scope);
      final controller = c.read(provider.notifier);
      await controller.loaded;
      final p = previewVocabulary(
          files: [
            csvFile('a.csv',
                'Event,Abbreviated Event,Display Name\nsupport_buy,sup_buy,Support bought')
          ],
          current: c.read(effectiveVocabularyProvider),
          scope: scope,
          baseRevision: 0);
      repo.gate = Completer<bool>();
      final applying = controller.apply(p);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(effectiveVocabularyProvider).eventLabel('sup_buy'),
          'Support item purchased');
      expect(await controller.apply(p), ApplyResult.busy);
      repo.gate!.complete(!fail);
      expect(await applying, fail ? ApplyResult.failed : ApplyResult.applied);
      expect(c.read(provider).snapshot.revision, fail ? 0 : 1);
      if (!fail) {
        final fresh = ProviderContainer(
            overrides: [vocabularyRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(fresh.dispose);
        await fresh.read(vocabularyProvider(scope).notifier).loaded;
        expect(fresh.read(effectiveVocabularyProvider).eventLabel('sup_buy'),
            'Support bought');
        expect(
            await fresh
                .read(vocabularyProvider(scope).notifier)
                .restoreDefaults(expectedRevision: 1),
            ApplyResult.applied);
        expect(fresh.read(effectiveVocabularyProvider).eventLabel('sup_buy'),
            'Support item purchased');
      }
    });
  }
  test(
      'scope switch while save pending cannot publish old labels into new scope',
      () async {
    final repo = MemoryVocabularyRepository();
    final c = ProviderContainer(
        overrides: [vocabularyRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    final a = c.read(currentVocabularyScopeProvider),
        controller = c.read(vocabularyProvider(a).notifier);
    await controller.loaded;
    final p = previewVocabulary(files: [
      csvFile('a.csv',
          'Event,Abbreviated Event,Display Name\nsupport_buy,sup_buy,From A')
    ], current: c.read(effectiveVocabularyProvider), scope: a, baseRevision: 0);
    repo.gate = Completer<bool>();
    final applying = controller.apply(p);
    c.read(baseUrlProvider.notifier).set('http://source-b');
    final b = c.read(currentVocabularyScopeProvider);
    await c.read(vocabularyProvider(b).notifier).loaded;
    repo.gate!.complete(true);
    expect(await applying, ApplyResult.stale);
    expect(c.read(effectiveVocabularyProvider).eventLabel('sup_buy'),
        'Support item purchased');
    expect(repo.data.containsKey(a), isTrue);
    expect(repo.data.containsKey(b), isFalse);
  });
  test('corrupt saved bytes remain intact and stale previews do not write',
      () async {
    final repo = MemoryVocabularyRepository();
    final scope = vocabularyScope(defaultBaseUrl);
    repo.data[scope] = '{"schemaVersion":9}';
    final c = ProviderContainer(
        overrides: [vocabularyRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    final controller = c.read(vocabularyProvider(scope).notifier);
    await controller.loaded;
    expect(c.read(vocabularyProvider(scope)).warning, isNotNull);
    expect(repo.data[scope], '{"schemaVersion":9}');
    final p = previewVocabulary(
        files: [csvFile('a.csv', 'Event,Abbreviated Event\nalpha,a')],
        current: c.read(effectiveVocabularyProvider),
        scope: scope,
        baseRevision: 100);
    expect(await controller.apply(p), ApplyResult.stale);
    expect(repo.writes, 0);
  });
  test('incremental imports retain mappings and storage is versioned',
      () async {
    final repo = MemoryVocabularyRepository();
    final c = ProviderContainer(
        overrides: [vocabularyRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    final scope = c.read(currentVocabularyScopeProvider),
        controller = c.read(vocabularyProvider(scope).notifier);
    await controller.loaded;
    for (final id in ['alpha', 'beta']) {
      final p = previewVocabulary(
          files: [csvFile('$id.csv', 'Event,Abbreviated Event\n$id,$id')],
          current: c.read(effectiveVocabularyProvider),
          scope: scope,
          baseRevision: c.read(vocabularyProvider(scope)).snapshot.revision);
      expect(await controller.apply(p), ApplyResult.applied);
    }
    expect(c.read(vocabularyProvider(scope)).snapshot.overrides.keys,
        containsAll(['alpha', 'beta']));
    expect((jsonDecode(repo.data[scope]!) as Map)['schemaVersion'], 1);
  });
}
