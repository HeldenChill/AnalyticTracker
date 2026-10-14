import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:analytic_app/src/presentation/event_catalog_import.dart';
import 'package:analytic_app/src/services/vocabulary_files.dart';
import 'package:analytic_app/src/state/event_vocabulary.dart';
import 'package:analytic_app/src/widgets/event_vocabulary_settings.dart';
import 'event_catalog_import_test.dart' show csvFile;
import 'event_vocabulary_state_test.dart' show MemoryVocabularyRepository;

class FakeVocabularyFiles implements VocabularyFiles {
  List<VocabularyFile> files = [];
  Uint8List? saved;
  @override
  Future<List<VocabularyFile>> pickCsvFiles() async => files;
  @override
  Future<String?> saveTemplate(Uint8List bytes) async {
    saved = bytes;
    return 'template.csv';
  }
}

void main() {
  Future<ProviderContainer> host(WidgetTester t, FakeVocabularyFiles files,
      MemoryVocabularyRepository repo) async {
    final c = ProviderContainer(overrides: [
      vocabularyFilesProvider.overrideWithValue(files),
      vocabularyRepositoryProvider.overrideWithValue(repo),
      vocabularyPreviewRunnerProvider
          .overrideWithValue((input) async => vocabularyPreviewWorker(input))
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
            home: Scaffold(
                body:
                    SingleChildScrollView(child: EventVocabularySettings())))));
    await t.pumpAndSettle();
    return c;
  }

  testWidgets('import previews applies edits and restores local vocabulary',
      (t) async {
    final files = FakeVocabularyFiles()
      ..files = [
        csvFile('a.csv',
            'Event,Abbreviated Event,Display Name,Description\nsupport_buy,sup_buy,Support bought,Meaning')
      ];
    final repo = MemoryVocabularyRepository(), c = await host(t, files, repo);
    await t.tap(find.byKey(const ValueKey('vocabulary-import')));
    await t.pumpAndSettle();
    expect(find.text('sup_buy'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('vocabulary-label-sup_buy')),
        'Support purchased today');
    await t.tap(find.byKey(const ValueKey('vocabulary-apply')));
    await t.pumpAndSettle();
    expect(c.read(effectiveVocabularyProvider).eventLabel('sup_buy'),
        'Support purchased today');
    expect(repo.writes, 1);
    await t.tap(find.byKey(const ValueKey('vocabulary-restore')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('vocabulary-restore-confirm')));
    await t.pumpAndSettle();
    expect(c.read(effectiveVocabularyProvider).eventLabel('sup_buy'),
        'Support item purchased');
  });
  testWidgets('cancel and malformed CSV do not write; template bytes are exact',
      (t) async {
    final files = FakeVocabularyFiles(), repo = MemoryVocabularyRepository();
    await host(t, files, repo);
    await t.tap(find.byKey(const ValueKey('vocabulary-import')));
    await t.pumpAndSettle();
    expect(repo.writes, 0);
    files.files = [csvFile('bad.csv', 'Event,Abbreviated Event\n"broken')];
    await t.tap(find.byKey(const ValueKey('vocabulary-import')));
    await t.pumpAndSettle();
    expect(find.textContaining('bad.csv'), findsWidgets);
    expect(
        t
            .widget<FilledButton>(
                find.byKey(const ValueKey('vocabulary-apply')))
            .onPressed,
        isNull);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('vocabulary-template')));
    await t.pumpAndSettle();
    expect(files.saved!.take(3).toList(), [239, 187, 191]);
    expect(repo.writes, 0);
  });
}
