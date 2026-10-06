import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'event_store.dart';

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
  return Filters(from: from, to: to, platform: _optional(q, 'platform'), version: _optional(q, 'version'));
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
      return _json(store.paramKeys(name, f.from, f.to, platform: f.platform, version: f.version));
    })
    ..get('/funnels', (Request req) => _json([for (final s in store.funnels.list()) s.toJson()]))
    ..post('/funnels/run', (Request req) async {
      final body = await _jsonBody(req);
      final def = _parseDef(body['def']);
      final f = _filters({
        for (final k in const ['from', 'to', 'platform', 'version'])
          if (body[k] is String) k: body[k] as String,
      });
      return _json(store.funnelEngine.run(def, f).toJson());
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
    ..get('/events/count', (Request req) {
      final q = req.url.queryParameters;
      final f = _filters(q);
      return _json([
        for (final c in store.counts(f.from, f.to,
            name: _optional(q, 'name'), platform: f.platform, version: f.version))
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
            platform: f.platform, version: f.version))
          b.toJson(),
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
        for (final s in store.funnel(steps, f.from, f.to, platform: f.platform, version: f.version))
          s.toJson(),
      ]);
    });

  return const Pipeline().addMiddleware(_cors()).addMiddleware(_errors()).addHandler(r.call);
}

