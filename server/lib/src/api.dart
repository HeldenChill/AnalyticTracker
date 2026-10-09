import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'event_store.dart';
import 'import_export.dart';
import 'raw_event.dart';

const _maxFunnelSteps = 10;

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'access-control-allow-headers': 'content-type',
};

class _BadRequest implements Exception {
  _BadRequest(this.message);
  final String message;
}

Response _json(Object? body, {int status = 200}) => Response(status,
    body: jsonEncode(body), headers: {'content-type': 'application/json'});

String _required(Map<String, String> q, String key) {
  final v = q[key]?.trim();
  if (v == null || v.isEmpty) throw _BadRequest('"$key" is required');
  return v;
}

(String, String) _range(Map<String, String> q) {
  final from = _required(q, 'from');
  final to = _required(q, 'to');
  if (!isValidDay(from)) throw _BadRequest('"from" must be a date YYYY-MM-DD');
  if (!isValidDay(to)) throw _BadRequest('"to" must be a date YYYY-MM-DD');
  if (from.compareTo(to) > 0) throw _BadRequest('"from" must be on or before "to"');
  return (from, to);
}

String? _optional(Map<String, String> q, String key) {
  final v = q[key]?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

Filters _filters(Map<String, String> q) {
  final (from, to) = _range(q);
  return Filters(
    from: from,
    to: to,
    platform: _optional(q, 'platform'),
    version: _optional(q, 'version'),
    includeTest: q['test'] == '1',
  );
}

/// `k` query: missing or "auto" → null (auto); else an integer 2..8.
int? _clusterK(Map<String, String> q) {
  final v = _optional(q, 'k');
  if (v == null || v == 'auto') return null;
  final k = int.tryParse(v);
  if (k == null || k < 2 || k > 8) throw _BadRequest('Invalid k');
  return k;
}

Future<Map<String, dynamic>> _jsonBody(Request req) async {
  final text = await req.readAsString();
  try {
    final v = jsonDecode(text);
    if (v is Map<String, dynamic>) return v;
  } on FormatException {
    // fall through to the error below
  }
  throw _BadRequest('Request body must be a JSON object');
}

FunnelDef _parseDef(Object? j) {
  if (j is! Map<String, dynamic>) throw _BadRequest('Malformed funnel definition');
  final FunnelDef def;
  try {
    def = FunnelDef.fromJson(j);
  } catch (_) {
    throw _BadRequest('Malformed funnel definition');
  }
  final error = def.validate();
  if (error != null) throw _BadRequest(error);
  return def;
}

Response _notFound(String what) => _json({'error': '$what not found'}, status: 404);

Middleware _cors() => (inner) => (req) async {
      if (req.method == 'OPTIONS') return Response.ok('', headers: _corsHeaders);
      final res = await inner(req);
      return res.change(headers: _corsHeaders);
    };

Middleware _errors() => (inner) => (req) async {
      try {
        return await inner(req);
      } on _BadRequest catch (e) {
        return _json({'error': e.message}, status: 400);
      } on ArgumentError catch (e) {
        return _json({'error': '${e.message}'}, status: 400);
      }
    };

Handler buildHandler(EventStore store) {
  final r = Router()
    ..get('/days', (Request req) => _json([for (final d in store.days()) d.toJson()]))
    ..get('/events/names', (Request req) => _json(store.eventNames()))
    ..get('/events/param-keys', (Request req) {
      final q = req.url.queryParameters;
      final name = _required(q, 'name');
      final f = _filters(q);
      return _json(store.paramKeys(name, f.from, f.to,
          platform: f.platform, version: f.version, includeTest: f.includeTest));
    })
    ..get('/events/user-prop-keys', (Request req) {
      final f = _filters(req.url.queryParameters);
      return _json(store.userPropKeys(f.from, f.to,
          platform: f.platform, version: f.version, includeTest: f.includeTest));
    })
    ..get('/funnels', (Request req) => _json([for (final s in store.funnels.list()) s.toJson()]))
    ..post('/funnels/run', (Request req) async {
      final body = await _jsonBody(req);
      final def = _parseDef(body['def']);
      final f = _filters({
        for (final k in const ['from', 'to', 'platform', 'version', 'test'])
          if (body[k] is String) k: body[k] as String,
      });
      FunnelBreakdown? breakdown;
      if (body['breakdown'] case final Map<String, dynamic> b) {
        try {
          breakdown = FunnelBreakdown.fromJson(b);
        } on FormatException catch (e) {
          throw _BadRequest(e.message);
        }
        final err = breakdown.validate();
        if (err != null) throw _BadRequest(err);
      }
      FunnelInterval? interval;
      if (body['interval'] case final String it) {
        try {
          interval = FunnelInterval.parse(it);
        } on FormatException catch (e) {
          throw _BadRequest(e.message);
        }
      } else if (body['interval'] != null) {
        throw _BadRequest('Unknown interval "${body['interval']}"');
      }
      return _json(store.funnelEngine.run(def, f, breakdown: breakdown, interval: interval).toJson());
    })
    ..post('/funnels/players', (Request req) async {
      final body = await _jsonBody(req);
      final def = _parseDef(body['def']);
      final f = _filters({
        for (final k in const ['from', 'to', 'platform', 'version', 'test'])
          if (body[k] is String) k: body[k] as String,
      });

      final stepRaw = body['step'];
      if (stepRaw is! int) throw _BadRequest('"step" must be an integer');
      if (stepRaw < 2 || stepRaw > def.steps.length) {
        throw _BadRequest('Step out of range: $stepRaw');
      }

      final outcomeRaw = body['outcome'];
      if (outcomeRaw is! String) throw _BadRequest('"outcome" is required');
      final FunnelPlayerOutcome outcome;
      try {
        outcome = FunnelPlayerOutcome.parse(outcomeRaw);
      } on FormatException {
        throw _BadRequest('Unknown outcome "$outcomeRaw"');
      }

      int limit = 100;
      if (body['limit'] != null) {
        if (body['limit'] is! int) throw _BadRequest('"limit" must be an integer');
        limit = body['limit'] as int;
        if (limit < 1 || limit > 500) throw _BadRequest('"limit" must be between 1 and 500');
      }

      FunnelBreakdown? breakdown;
      if (body['breakdown'] case final Map<String, dynamic> b) {
        try {
          breakdown = FunnelBreakdown.fromJson(b);
        } on FormatException catch (e) {
          throw _BadRequest(e.message);
        }
        final err = breakdown.validate();
        if (err != null) throw _BadRequest(err);
      }

      final segment = body['segment'] as String?;

      return _json(store.funnelEngine.players(
        def,
        f,
        step: stepRaw,
        outcome: outcome,
        breakdown: breakdown,
        segment: segment,
        limit: limit,
      ).toJson());
    })
    ..post('/import', (Request req) async {
      // Body = BigQuery export file text (see parseBigQueryExport). The server
      // never reads a client-supplied path.
      final text = await req.readAsString();
      if (text.trim().isEmpty) throw _BadRequest('Request body must be a BigQuery export');
      final Map<String, List<RawEvent>> byDay;
      try {
        byDay = parseBigQueryExport(text);
      } on FormatException catch (e) {
        throw _BadRequest(e.message);
      }
      final days = byDay.keys.toList()..sort();
      if (req.url.queryParameters['dryRun'] == '1') {
        return _json([
          for (final d in days) {'day': d, 'rows': byDay[d]!.length, 'stored': store.rowCount(d)},
        ]);
      }
      for (final d in days) {
        store.replaceDay(d, byDay[d]!);
      }
      return _json({for (final d in days) d: byDay[d]!.length});
    })
    ..post('/funnels', (Request req) async {
      final def = _parseDef(await _jsonBody(req));
      return _json(store.funnels.create(def).toJson(), status: 201);
    })
    ..put('/funnels/<id>', (Request req, String id) async {
      final def = _parseDef(await _jsonBody(req));
      final saved = store.funnels.update(int.tryParse(id) ?? -1, def);
      return saved == null ? _notFound('Funnel $id') : _json(saved.toJson());
    })
    ..delete('/funnels/<id>', (Request req, String id) {
      return store.funnels.delete(int.tryParse(id) ?? -1) ? Response(204) : _notFound('Funnel $id');
    })
    ..get('/filters', (Request req) => _json(store.metrics.filterOptions().toJson()))
    ..get('/overview', (Request req) =>
        _json(store.metrics.overview(_filters(req.url.queryParameters)).toJson()))
    ..get('/retention', (Request req) =>
        _json(store.metrics.retention(_filters(req.url.queryParameters)).toJson()))
    ..get('/progression', (Request req) =>
        _json(store.metrics.progression(_filters(req.url.queryParameters)).toJson()))
    ..get('/analysis/clusters', (Request req) {
      final q = req.url.queryParameters;
      final f = _filters(q);
      return _json(store.clusters(f, k: _clusterK(q)).toJson());
    })
    ..get('/analysis/churn', (Request req) {
      final q = req.url.queryParameters;
      final f = _filters(q);
      return _json(store.churn(f).toJson());
    })
    ..get('/analysis/levels', (Request req) {
      final q = req.url.queryParameters;
      final f = _filters(q);
      return _json(store.levels(f).toJson());
    })
    ..get('/events/count', (Request req) {
      final q = req.url.queryParameters;
      final f = _filters(q);
      return _json([
        for (final c in store.counts(f.from, f.to,
            name: _optional(q, 'name'), platform: f.platform, version: f.version, includeTest: f.includeTest))
          c.toJson(),
      ]);
    })
    ..get('/events/param', (Request req) {
      final q = req.url.queryParameters;
      final name = _required(q, 'name');
      final key = _required(q, 'key');
      final f = _filters(q);
      return _json([
        for (final b in store.paramBreakdown(name, key, f.from, f.to,
            platform: f.platform, version: f.version, includeTest: f.includeTest))
          b.toJson(),
      ]);
    })
    ..get('/players/<uid>/events', (Request req, String uid) {
      final q = req.url.queryParameters;
      final fromTsRaw = q['fromTs'];
      final toTsRaw = q['toTs'];
      if (fromTsRaw == null || toTsRaw == null) {
        throw _BadRequest('"fromTs" and "toTs" are required');
      }
      final fromTs = int.tryParse(fromTsRaw);
      final toTs = int.tryParse(toTsRaw);
      if (fromTs == null || toTs == null) {
        throw _BadRequest('"fromTs" and "toTs" must be integer microseconds');
      }
      if (fromTs > toTs) throw _BadRequest('"fromTs" must be on or before "toTs"');

      int limit = 300;
      if (q['limit'] != null) {
        final l = int.tryParse(q['limit']!);
        if (l == null || l < 1 || l > 1000) {
          throw _BadRequest('"limit" must be between 1 and 1000');
        }
        limit = l;
      }
      final includeTest = q['test'] == '1';

      return _json([
        for (final ev in store.playerEvents(uid, fromTs, toTs, includeTest: includeTest, limit: limit))
          ev.toJson(),
      ]);
    })
    ..get('/funnel', (Request req) {
      final q = req.url.queryParameters;
      final steps = _required(q, 'steps')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (steps.isEmpty) throw _BadRequest('"steps" must list at least one event');
      if (steps.length > _maxFunnelSteps) {
        throw _BadRequest('"steps" allows at most $_maxFunnelSteps events');
      }
      final f = _filters(q);
      return _json([
        for (final s in store.funnel(steps, f.from, f.to,
            platform: f.platform, version: f.version, includeTest: f.includeTest))
          s.toJson(),
      ]);
    });

  return const Pipeline().addMiddleware(_cors()).addMiddleware(_errors()).addHandler(r.call);
}

