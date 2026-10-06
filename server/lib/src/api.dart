import 'dart:convert';

import 'package:analytic_shared/analytic_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'event_store.dart';

const _maxFunnelSteps = 10;

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, OPTIONS',
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
    ..get('/events/count', (Request req) {
      final q = req.url.queryParameters;
      final (from, to) = _range(q);
      final name = q['name']?.trim();
      return _json([
        for (final c in store.counts(from, to, name: (name == null || name.isEmpty) ? null : name))
          c.toJson(),
      ]);
    })
    ..get('/events/param', (Request req) {
      final q = req.url.queryParameters;
      final name = _required(q, 'name');
      final key = _required(q, 'key');
      final (from, to) = _range(q);
      return _json([for (final b in store.paramBreakdown(name, key, from, to)) b.toJson()]);
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
      final (from, to) = _range(q);
      return _json([for (final f in store.funnel(steps, from, to)) f.toJson()]);
    });

  return const Pipeline().addMiddleware(_cors()).addMiddleware(_errors()).addHandler(r.call);
}
