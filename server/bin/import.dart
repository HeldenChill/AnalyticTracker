import 'dart:io';

import 'package:analytic_server/analytic_server.dart';

/// Usage: dart run bin/import.dart config.json imports/file1.json [more.json ...]
/// Loads manual BigQuery console exports. Days present in a file replace
/// that day's stored rows. Exit codes: 0 ok, 1 a file failed, 2 bad usage/config.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run bin/import.dart config.json <export.json>...');
    exitCode = 2;
    return;
  }
  final Config config;
  try {
    config = Config.load(args.first);
  } catch (e) {
    stderr.writeln('config error: $e');
    exitCode = 2;
    return;
  }
  final store = EventStore.open(config.dbPath);
  try {
    for (final path in args.skip(1)) {
      try {
        final result = importExport(await File(path).readAsString(), store);
        final total = result.values.fold<int>(0, (a, b) => a + b);
        stdout.writeln('$path: $total rows, ${result.length} days '
            '(${result.isEmpty ? '-' : '${result.keys.first} .. ${result.keys.last}'})');
      } catch (e) {
        stderr.writeln('$path: FAILED $e');
        exitCode = 1;
      }
    }
  } finally {
    store.close();
  }
}
