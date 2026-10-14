import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:analytic_app/src/presentation/event_catalog.dart';
import 'package:analytic_app/src/presentation/event_catalog_import.dart';
import 'package:analytic_app/src/presentation/strict_csv.dart';

VocabularyFile csvFile(String name, String content) =>
    VocabularyFile(name, Uint8List.fromList(utf8.encode(content)));
ImportPreview preview(List<VocabularyFile> files, [EventCatalog? current]) =>
    previewVocabulary(
        files: files,
        current: current ?? EventCatalog({}),
        scope: 'fixture',
        baseRevision: 4);

void main() {
  test('tutorial reimport updates multiple IDs without treating baseline as a conflicting row', () {
    final base=EventCatalog({'tut':EventMeaning(rawId:'tut',fullName:'tutorial',label:'Tutorial',
      tutorials:{'Tut_1':const TutorialMeaning(id:'Tut_1',label:'First',content:'Old 1'),
        'Tut_2':const TutorialMeaning(id:'Tut_2',label:'Second',content:'Old 2')})});
    final p=preview([csvFile('t.csv','Event,Abbreviated Event,Parameter,Content\n'
      'tutorial,tut,id: Tut_1,New 1\ntutorial,tut,id: Tut_2,New 2')],base);
    expect(p.canApply,isTrue);
    expect(p.replacements['tut']!.tutorials['Tut_1']!.content,'New 1');
    expect(p.replacements['tut']!.tutorials['Tut_2']!.content,'New 2');
    expect(preview([csvFile('t.csv','Event,Abbreviated Event,Parameter,Content\n'
      'tutorial,tut,id: Tut_1,New 1\ntutorial,tut,id: Tut_1,Conflict')],base).canApply,isFalse);
  });
  test('strict parser handles quotes newlines and all endings', () {
    expect(
        parseStrictCsv('a,b\r\n"a""b","x\ny"\nc,\r')
            .map((r) => r.cells)
            .toList(),
        [
          ['a', 'b'],
          ['a"b', 'x\ny'],
          ['c', '']
        ]);
    for (final input in ['"unterminated', 'a"b,c', '"a"x,c']) {
      expect(() => parseStrictCsv(input), throwsFormatException);
    }
  });
  test('full name update clears stale meanings but leaves unrelated records',
      () {
    final base = EventCatalog({
      'sup_buy': EventMeaning(
          rawId: 'sup_buy',
          fullName: 'support_buy',
          label: 'Support purchased',
          description: 'Old'),
      'pet_buy': EventMeaning(
          rawId: 'pet_buy', fullName: 'pet_buy', label: 'Pet purchased')
    });
    final p = preview([
      csvFile(
          'new.csv',
          '\uFEFFnotes,,,\r\nEvent,Abbreviated Event,Display Name,Description\r\n'
              'support_refund,sup_buy,"Support refunded, successfully","Returned\nitem"\r\n')
    ], base);
    expect(p.canApply, isTrue);
    expect(p.replacements['sup_buy']!.label, 'Support refunded, successfully');
    expect(p.replacements['sup_buy']!.description, 'Returned\nitem');
    final minimal = preview([
      csvFile('minimal.csv', 'Event,Abbreviated Event\nstage_refund,sup_buy\n')
    ], base);
    expect(minimal.replacements['sup_buy']!.description, isNull);
    expect(base.overlay(minimal.replacements).eventLabel('pet_buy'),
        'Pet purchased');
  });
  test('missing description preserves unchanged name; explicit blank clears it',
      () {
    final base = EventCatalog({
      'a': EventMeaning(
          rawId: 'a', fullName: 'alpha', label: 'Alpha', description: 'Meaning')
    });
    expect(
        preview([csvFile('a.csv', 'Event,Abbreviated Event\nalpha,a')], base)
            .replacements['a']!
            .description,
        'Meaning');
    expect(
        preview([
          csvFile('a.csv', 'Event,Abbreviated Event,Description\nalpha,a,')
        ], base)
            .replacements['a']!
            .description,
        isNull);
  });
  test('conflicting aliases block in either file order', () {
    final a = csvFile('a.csv', 'Event,Abbreviated Event\nalpha,x');
    final b = csvFile('b.csv', 'Event,Abbreviated Event\nbeta,x');
    for (final files in [
      [a, b],
      [b, a]
    ]) {
      final p = preview(files);
      expect(p.canApply, isFalse);
      expect(p.issues.any((i) => i.message.contains('Conflicting')), isTrue);
    }
  });
  test('invalid encoding headers and required cells block with location', () {
    for (final file in [
      VocabularyFile('bad.csv', Uint8List.fromList([0xc3, 0x28])),
      csvFile('bad.csv', 'Event,Event,Abbreviated Event\nalpha,alpha,a'),
      csvFile('bad.csv', 'Event,Abbreviated Event\nalpha,')
    ]) {
      final p = preview([file]);
      expect(p.canApply, isFalse);
      expect(p.issues.first.fileName, 'bad.csv');
    }
  });
  test('annotations skip but empty files cannot apply', () {
    final p = preview([
      csvFile('a.csv', 'Event,Abbreviated Event\n(bỏ) uninstall,\nalpha,a')
    ]);
    expect(p.canApply, isTrue);
    expect(p.mappings.length, 1);
    expect(p.issues.single.severity, IssueSeverity.warning);
    expect(
        preview([csvFile('empty.csv', 'Event,Abbreviated Event\n')]).canApply,
        isFalse);
  });
  test('tutorial optional IDs merge with contextual parameters', () {
    final p = preview([
      csvFile(
          't.csv',
          'Event,Abbreviated Event,Parameter,Content,Parameter Abbreviation Map,Optional Mode B Template\n'
              'tutorial,tut,id: Tut_1,First,"id -> id\nstep -> step",tut_{id}_{step}\n'
              'tutorial,tut,id: Tut_opt_1,Optional,"id -> id\nstep -> step",tut_{id}_{step}')
    ]);
    expect(p.canApply, isTrue);
    expect(p.replacements['tut']!.tutorials.length, 2);
  });
  test('supported template overlap blocks; exact event takes precedence', () {
    final p = preview([
      csvFile(
          'p.csv',
          'Event,Abbreviated Event,Optional Mode B Template\n'
              'a,a,stg_{stage}_start\nb,b,stg_{wave}_start')
    ]);
    expect(p.canApply, isFalse);
    final c = EventCatalog({
      'a': EventMeaning(
          rawId: 'a',
          fullName: 'alpha',
          label: 'Alpha',
          modeBTemplate: 'stg_{stage}_start'),
      'stg_3_start':
          EventMeaning(rawId: 'stg_3_start', fullName: 'exact', label: 'Exact')
    });
    expect(c.eventLabel('stg_3_start'), 'Exact');
  });
  test('preview edits retain ID and survive JSON worker round trip', () {
    final p = preview([csvFile('a.csv', 'Event,Abbreviated Event\nalpha,a')])
        .edit('a', label: 'Readable', description: 'Meaning');
    expect(ImportPreview.fromJson(p.toJson()).replacements['a']!.label,
        'Readable');
    expect(
        () => p.edit('a', label: ' ', description: null), throwsArgumentError);
  });
  test('byte and data record limits reject oversized batches', () {
    expect(
        preview([
          VocabularyFile('large.csv', Uint8List(maxVocabularyBytes + 1))
        ]).canApply,
        isFalse);
    final content =
        'Event,Abbreviated Event\n${List.generate(maxVocabularyRecords + 1, (i) => 'alpha$i,a$i').join('\n')}';
    expect(preview([csvFile('many.csv', content)]).canApply, isFalse);
  });
}
