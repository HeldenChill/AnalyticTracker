import 'dart:math' as math;

class ChartPoint {
  const ChartPoint(
    this.x,
    this.value, {
    required this.label,
    this.incomplete = false,
  });

  final double x;
  final double? value;
  final String label;
  final bool incomplete;
}

class ChartSeries {
  const ChartSeries({
    required this.id,
    required this.label,
    required this.points,
  });

  final String id;
  final String label;
  final List<ChartPoint> points;
}

class ChartBounds {
  const ChartBounds(this.minX, this.maxX, this.minY, this.maxY);

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}

class ChartSegment {
  const ChartSegment(this.points, {required this.incomplete});

  final List<ChartPoint> points;
  final bool incomplete;
}

ChartBounds chartBounds(List<ChartSeries> series, {bool includeZero = true}) {
  final seenIds = <String>{};
  for (final s in series) {
    if (s.id.isEmpty) {
      throw ArgumentError('Series id must not be empty');
    }
    if (!seenIds.add(s.id)) {
      throw ArgumentError('Duplicate series id: ${s.id}');
    }
    for (var i = 0; i < s.points.length; i++) {
      final p = s.points[i];
      if (!p.x.isFinite) {
        throw ArgumentError('Point x must be finite, got ${p.x}');
      }
      if (p.value != null && !p.value!.isFinite) {
        throw ArgumentError('Point value must be finite or null, got ${p.value}');
      }
      if (i > 0 && p.x <= s.points[i - 1].x) {
        throw ArgumentError('Points must have strictly increasing x coordinates');
      }
    }
  }

  final allX = <double>[];
  final allY = <double>[];

  for (final s in series) {
    for (final p in s.points) {
      allX.add(p.x);
      if (p.value != null) {
        allY.add(p.value!);
      }
    }
  }

  double minX;
  double maxX;

  if (allX.isEmpty) {
    minX = 0.0;
    maxX = 1.0;
  } else {
    final minXVal = allX.reduce(math.min);
    final maxXVal = allX.reduce(math.max);
    if (minXVal == maxXVal) {
      minX = minXVal;
      maxX = minXVal + 1.0;
      if (maxX == minX) {
        final delta = math.max(minXVal.abs() * 0.05, 1.0);
        if ((minXVal + delta).isFinite && (minXVal + delta) > minXVal) {
          maxX = minXVal + delta;
        } else if ((minXVal - delta).isFinite && (minXVal - delta) < minXVal) {
          minX = minXVal - delta;
          maxX = minXVal;
        } else {
          throw ArgumentError('Cannot establish finite x span for $minXVal');
        }
      }
    } else {
      minX = minXVal;
      maxX = maxXVal;
    }
  }

  if (!minX.isFinite || !maxX.isFinite || minX >= maxX || !(maxX - minX).isFinite) {
    throw ArgumentError('Cannot establish finite x domain');
  }

  if (includeZero) {
    allY.add(0.0);
  }

  double minY;
  double maxY;

  if (allY.isEmpty || allY.every((y) => y == 0.0)) {
    minY = 0.0;
    maxY = 1.0;
  } else {
    final rawMin = allY.reduce(math.min);
    final rawMax = allY.reduce(math.max);

    if (rawMin == rawMax) {
      final delta = math.max(rawMin.abs() * 0.05, 1.0);
      minY = rawMin - delta;
      maxY = rawMax + delta;
    } else {
      final span = rawMax - rawMin;
      if (!span.isFinite || span <= 0) {
        throw ArgumentError('Unrepresentable span: $rawMin to $rawMax');
      }
      final delta = span * 0.05;
      if (includeZero && rawMin >= 0) {
        minY = 0.0;
        maxY = (rawMax + delta).isFinite ? rawMax + delta : rawMax;
      } else {
        minY = (rawMin - delta).isFinite ? rawMin - delta : rawMin;
        maxY = (rawMax + delta).isFinite ? rawMax + delta : rawMax;
      }
    }
  }

  if (!minY.isFinite || !maxY.isFinite || minY >= maxY || !(maxY - minY).isFinite) {
    throw ArgumentError('Cannot establish finite y domain');
  }

  return ChartBounds(minX, maxX, minY, maxY);
}

List<ChartSegment> splitSeries(List<ChartPoint> points) {
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    if (!p.x.isFinite) {
      throw ArgumentError('Point x must be finite, got ${p.x}');
    }
    if (p.value != null && !p.value!.isFinite) {
      throw ArgumentError('Point value must be finite or null, got ${p.value}');
    }
    if (i > 0 && p.x <= points[i - 1].x) {
      throw ArgumentError('Points must have strictly increasing x coordinates');
    }
  }

  final segments = <ChartSegment>[];
  var i = 0;
  while (i < points.length) {
    if (points[i].value == null) {
      i++;
      continue;
    }
    final runStart = i;
    while (i < points.length && points[i].value != null) {
      i++;
    }
    final run = points.sublist(runStart, i);
    if (run.length == 1) {
      segments.add(ChartSegment(run, incomplete: run[0].incomplete));
    } else {
      var edgeStart = 0;
      var curEdgeIncomplete = run[0].incomplete || run[1].incomplete;
      for (var e = 1; e < run.length - 1; e++) {
        final nextEdgeIncomplete = run[e].incomplete || run[e + 1].incomplete;
        if (nextEdgeIncomplete != curEdgeIncomplete) {
          segments.add(
            ChartSegment(
              run.sublist(edgeStart, e + 1),
              incomplete: curEdgeIncomplete,
            ),
          );
          edgeStart = e;
          curEdgeIncomplete = nextEdgeIncomplete;
        }
      }
      segments.add(
        ChartSegment(
          run.sublist(edgeStart, run.length),
          incomplete: curEdgeIncomplete,
        ),
      );
    }
  }
  return segments;
}

class SeriesStyleRegistry {
  final Map<String, int> _slots = {};

  void registerAll(Iterable<String> ids) {
    for (final id in ids) {
      if (id.isEmpty) {
        throw ArgumentError('Series id cannot be empty');
      }
    }
    final fresh = ids.toSet().where((id) => !_slots.containsKey(id)).toList()..sort();
    for (final id in fresh) {
      _slots[id] = _slots.length;
    }
  }

  int slotFor(String id) {
    if (id.isEmpty) {
      throw ArgumentError('Series id cannot be empty');
    }
    if (!_slots.containsKey(id)) {
      registerAll([id]);
    }
    return _slots[id]!;
  }
}
