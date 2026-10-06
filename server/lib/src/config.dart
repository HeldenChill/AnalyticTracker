import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class Config {
  Config._({
    required this.projectId,
    required this.datasetId,
    required this.location,
    required this.keyFile,
    required this.dbPath,
    required this.port,
  });

  final String projectId;
  final String datasetId;
  final String? location;
  final String keyFile;
  final String dbPath;
  final int port;

  static Config load(String path) {
    final raw = jsonDecode(File(path).readAsStringSync());
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('config root must be a JSON object');
    }
    return fromJson(raw, baseDir: p.dirname(p.absolute(path)));
  }

  static Config fromJson(Map<String, dynamic> json, {required String baseDir}) {
    String req(String k) {
      final v = json[k];
      if (v is! String || v.isEmpty) {
        throw FormatException('config: "$k" must be a non-empty string');
      }
      return v;
    }

    String? opt(String k) {
      final v = json[k];
      if (v == null) return null;
      if (v is! String || v.isEmpty) {
        throw FormatException('config: "$k" must be a non-empty string');
      }
      return v;
    }

    String resolve(String v) => p.normalize(p.isAbsolute(v) ? v : p.join(baseDir, v));

    final port = json['port'] ?? 8080;
    if (port is! int || port <= 0 || port > 65535) {
      throw const FormatException('config: "port" must be an integer 1-65535');
    }
    return Config._(
      projectId: req('projectId'),
      datasetId: req('datasetId'),
      location: opt('location'),
      keyFile: resolve(req('keyFile')),
      dbPath: resolve(opt('dbPath') ?? 'data/events.db'),
      port: port,
    );
  }
}
