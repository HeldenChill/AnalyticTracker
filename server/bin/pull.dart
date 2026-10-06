import 'dart:io';

import 'package:analytic_server/analytic_server.dart';
import 'package:analytic_shared/analytic_shared.dart';

/// Usage: dart run bin/pull.dart [config.json]
/// Exit codes: 0 ok, 1 some days failed, 2 aborted (config/auth/list error).
Future<void> main(List<String> args) async {
  final stamp = DateTime.now().toIso8601String();
  EventStore? store;
  BigQuerySource? source;
  try {
    final config = Config.load(args.isNotEmpty ? args.first : 'config.json');
    store = EventStore.open(config.dbPath);
    source = await BigQuerySource.connect(config);
    final result = await runPull(source, store,
        today: formatDay(DateTime.now().toUtc()),
        log: (m) => stdout.writeln('[$stamp] $m'));
    stdout.writeln('[$stamp] done: ${result.pulled.length} pulled, ${result.failed.length} failed');
    exitCode = result.ok ? 0 : 1;
  } catch (e, st) {
    stderr.writeln('[$stamp] pull aborted: $e\n$st');
    exitCode = 2;
  } finally {
    source?.close();
    store?.close();
  }
}
