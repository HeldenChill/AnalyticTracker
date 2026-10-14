import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:analytic_app/src/presentation/event_catalog.dart';
import 'package:analytic_app/src/presentation/event_catalog_data.dart';
import 'package:analytic_app/src/presentation/event_catalog_import.dart';

void main() {
  test('all supplied CSV rows normalize without losing optional tutorials', () {
    final files = Directory('../csv')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.csv'))
        .map((f) => VocabularyFile(
            f.uri.pathSegments.last, Uint8List.fromList(f.readAsBytesSync())))
        .toList();
    final p = previewVocabulary(
        files: files,
        current: EventCatalog({}),
        scope: 'baseline',
        baseRevision: 0);
    expect(p.issues.where((i) => i.severity == IssueSeverity.error), isEmpty);
    expect(p.replacements.length, 60);
    expect(p.replacements['tut']!.tutorials.length, 24);
    expect(p.replacements['tut']!.tutorials.containsKey('Tut_opt_4'), isTrue);
  });
  test(
      'reviewed bundle preserves session scope contextual IDs and minute units',
      () {
    expect(bundledEventCatalog.eventLabel('stg_start'), 'Stage started');
    expect(bundledEventCatalog.eventLabel('ftu_stg_start'),
        'Stage started in first play session');
    expect(bundledEventCatalog.parameterLabel('stg_cmp', 'time_min'),
        'Play time in minutes');
    expect(bundledEventCatalog.parameterLabel('skl_pick', 'id'), 'Skill ID');
    expect(bundledEventCatalog.parameterLabel('trn_use', 'id'), 'Terrain ID');
    expect(bundledEventCatalog.meaning('tut')!.tutorials['Tut_opt_4']!.label,
        'Tut_opt_4');
    expect(bundledEventCatalog.eventLabel('stg_3_fail_wa_2'),
        'Stage failed — Stage 3, Wave 2');
  });
}
