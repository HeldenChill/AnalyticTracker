import 'dart:async';
import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String baseUrl, {http.Client? client})
      : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _http = client ?? http.Client();

  final Uri _base;
  final http.Client _http;
  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    _closed = true;
    _http.close();
  }

  Future<List<dynamic>> _getList(String path, [Map<String, String> query = const {}]) async {
    final resolved = _base.resolve(path);
    final uri = query.isEmpty ? resolved : resolved.replace(queryParameters: query);
    final http.Response res;
    try {
      res = await _http.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Cannot reach server at $_base ($e)');
    }
    Object? body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      body = null;
    }
    if (res.statusCode != 200) {
      if (body is Map && body['error'] is String) throw ApiException(body['error'] as String);
      throw ApiException('HTTP ${res.statusCode}');
    }
    if (body is! List) throw ApiException('Unexpected response from $path');
    return body;
  }

  Future<List<DayStat>> days() async =>
      [for (final j in await _getList('days')) DayStat.fromJson(j as Map<String, dynamic>)];

  Future<List<String>> eventNames() async =>
      [for (final j in await _getList('events/names')) j as String];

  Future<List<EventCount>> counts(String from, String to, {String? name}) async => [
        for (final j in await _getList('events/count', {
          'from': from,
          'to': to,
          if (name != null) 'name': name,
        }))
          EventCount.fromJson(j as Map<String, dynamic>),
      ];

  Future<List<ParamBucket>> param(String name, String key, String from, String to) async => [
        for (final j in await _getList('events/param', {'name': name, 'key': key, 'from': from, 'to': to}))
          ParamBucket.fromJson(j as Map<String, dynamic>),
      ];

  Future<List<FunnelStep>> funnel(String stepsCsv, String from, String to) async => [
        for (final j in await _getList('funnel', {'steps': stepsCsv, 'from': from, 'to': to}))
          FunnelStep.fromJson(j as Map<String, dynamic>),
      ];
}
