import 'dart:io';

import 'package:analytic_server/analytic_server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:http/http.dart' as http;

/// Usage: dart run server/bin/mcp.dart [--server http://localhost:8080]
/// stdout carries the MCP protocol only; diagnostics go to stderr.
void main(List<String> args) {
  final i = args.indexOf('--server');
  final baseUrl = (i >= 0 && i + 1 < args.length) ? args[i + 1] : 'http://localhost:8080';
  stderr.writeln('analytic-tracker MCP -> $baseUrl');
  AnalyticMcpServer(
    stdioChannel(input: stdin, output: stdout),
    AnalyticTools(baseUrl, http.Client()),
  );
}
