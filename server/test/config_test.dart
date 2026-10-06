import 'dart:convert';
import 'dart:io';

import 'package:analytic_server/analytic_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final base = p.join(Directory.systemTemp.path, 'cfg');

  test('applies defaults and resolves relative paths', () {
    final c = Config.fromJson({
      'projectId': 'pvm-prod',
      'datasetId': 'analytics_123',
      'keyFile': 'secrets/key.json',
    }, baseDir: base);
    expect(c.projectId, 'pvm-prod');
    expect(c.datasetId, 'analytics_123');
    expect(c.location, isNull);
    expect(c.port, 8080);
    expect(c.keyFile, p.normalize(p.join(base, 'secrets/key.json')));
    expect(c.dbPath, p.normalize(p.join(base, 'data/events.db')));
  });

  test('keeps absolute paths and explicit values', () {
    final abs = p.join(Directory.systemTemp.path, 'k.json');
    final c = Config.fromJson({
      'projectId': 'p',
      'datasetId': 'd',
      'keyFile': abs,
      'dbPath': 'x.db',
      'location': 'US',
      'port': 9000,
    }, baseDir: base);
    expect(c.keyFile, abs);
    expect(c.location, 'US');
    expect(c.port, 9000);
  });

  test('missing or wrong-typed fields name the field', () {
    expect(() => Config.fromJson({'projectId': 'p', 'keyFile': 'k'}, baseDir: base),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('datasetId'))));
    expect(() => Config.fromJson({'projectId': 'p', 'datasetId': 'd', 'keyFile': 'k', 'port': '80'}, baseDir: base),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('port'))));
  });

  test('load reads file and resolves against its directory', () {
    final dir = Directory.systemTemp.createTempSync('at_cfg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File(p.join(dir.path, 'config.json'))
      ..writeAsStringSync(jsonEncode({'projectId': 'p', 'datasetId': 'd', 'keyFile': 'k.json'}));
    expect(Config.load(f.path).keyFile, p.normalize(p.join(dir.path, 'k.json')));
  });

  test('load rejects non-object JSON', () {
    final dir = Directory.systemTemp.createTempSync('at_cfg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File(p.join(dir.path, 'config.json'))..writeAsStringSync('[]');
    expect(() => Config.load(f.path), throwsFormatException);
  });
}
