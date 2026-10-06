import 'dart:io';

import 'package:analytic_server/analytic_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Usage: dart run bin/server.dart [config.json]
Future<void> main(List<String> args) async {
  final config = Config.load(args.isNotEmpty ? args.first : 'config.json');
  final store = EventStore.open(config.dbPath);
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(buildHandler(store));
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, config.port);
  stdout.writeln('AnalyticTracker server on http://0.0.0.0:${server.port} (db: ${config.dbPath})');
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: true);
    store.close();
    exit(0);
  });
}
