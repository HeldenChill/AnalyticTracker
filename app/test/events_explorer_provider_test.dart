import 'dart:async';
import 'dart:convert';
import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/state/events_explorer.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('optional previous failure preserves parsed current observations', () async {
    const f = Filters(
      from: '2026-10-01',
      to: '2026-10-04',
      platform: 'IOS',
      version: '2.0',
      includeTest: true,
    );
    final client = ApiClient('http://fixture', client: MockClient((request) async {
      if (request.url.path == '/days') {
        return http.Response(jsonEncode([
          for (final day in daysBetween('2026-09-27', '2026-10-04'))
            DayStat(
              day: day,
              rowCount: day == '2026-10-01' ? 8 : 0,
              pulledAt: '2026-10-05T01:00:00Z',
            ).toJson(),
        ]), 200);
      }
      expect(request.url.path, '/events/count');
      final previous = request.url.queryParameters['from'] == '2026-09-27';
      expect(
        request.url.queryParameters,
        previous
            ? {
                'from': '2026-09-27',
                'to': '2026-09-30',
                'platform': 'IOS',
                'version': '2.0',
                'test': '1',
              }
            : f.toQuery(),
      );
      if (previous) return http.Response('comparison failed', 500);
      return http.Response(jsonEncode([
        const EventCount(day: '2026-10-01', eventName: 'pet_buy', count: 8).toJson(),
      ]), 200);
    }));
    addTearDown(client.close);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    final payload = await container.read(
      eventsExplorerProvider((filters: f, compare: true)).future,
    );
    expect(payload.current.single.eventName, 'pet_buy');
    expect(payload.current.single.count, 8);
    expect(payload.previous, isNull);
    expect(payload.previousError, isA<ApiException>().having((e) => e.statusCode, 'status', 500));
  });

  test('compare: false causes no previous request', () async {
    const f = Filters(from: '2026-10-01', to: '2026-10-04');
    var previousRequested = false;
    final client = ApiClient('http://fixture', client: MockClient((request) async {
      if (request.url.path == '/days') {
        return http.Response(jsonEncode(<dynamic>[]), 200);
      }
      if (request.url.path == '/events/count') {
        if (request.url.queryParameters['from'] == '2026-09-27') {
          previousRequested = true;
        }
        return http.Response(jsonEncode([
          const EventCount(day: '2026-10-01', eventName: 'pet_buy', count: 8).toJson(),
        ]), 200);
      }
      return http.Response('not found', 404);
    }));
    addTearDown(client.close);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final payload = await container.read(
      eventsExplorerProvider((filters: f, compare: false)).future,
    );
    expect(previousRequested, isFalse);
    expect(payload.previous, isNull);
    expect(payload.previousError, isNull);
    expect(payload.current.length, 1);
  });

  test('requests for both periods include exact gameplay filter parameters', () async {
    const f = Filters(
      from: '2026-10-01',
      to: '2026-10-04',
      platform: 'IOS',
      version: '2.0',
      includeTest: true,
    );
    final recordedQueries = <Map<String, String>>[];
    final client = ApiClient('http://fixture', client: MockClient((request) async {
      if (request.url.path == '/days') {
        return http.Response(jsonEncode(<dynamic>[]), 200);
      }
      if (request.url.path == '/events/count') {
        recordedQueries.add(request.url.queryParameters);
        return http.Response(jsonEncode([
          const EventCount(day: '2026-10-01', eventName: 'pet_buy', count: 5).toJson(),
        ]), 200);
      }
      return http.Response('not found', 404);
    }));
    addTearDown(client.close);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final payload = await container.read(
      eventsExplorerProvider((filters: f, compare: true)).future,
    );
    expect(payload.current.length, 1);
    expect(payload.previous?.length, 1);
    expect(recordedQueries, hasLength(2));
    expect(recordedQueries, contains(equals({
      'from': '2026-10-01',
      'to': '2026-10-04',
      'platform': 'IOS',
      'version': '2.0',
      'test': '1',
    })));
    expect(recordedQueries, contains(equals({
      'from': '2026-09-27',
      'to': '2026-09-30',
      'platform': 'IOS',
      'version': '2.0',
      'test': '1',
    })));
  });

  test('two queries completing out of order keep host on requested key', () async {
    final completerA = Completer<http.Response>();
    final completerB = Completer<http.Response>();

    const fA = Filters(from: '2026-10-01', to: '2026-10-02');
    const fB = Filters(from: '2026-10-03', to: '2026-10-04');

    final client = ApiClient('http://fixture', client: MockClient((request) async {
      if (request.url.path == '/days') {
        return http.Response(jsonEncode(<dynamic>[]), 200);
      }
      if (request.url.queryParameters['from'] == '2026-10-01') {
        return completerA.future;
      }
      if (request.url.queryParameters['from'] == '2026-10-03') {
        return completerB.future;
      }
      return http.Response(jsonEncode(<dynamic>[]), 200);
    }));
    addTearDown(client.close);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final futureA = container.read(eventsExplorerProvider((filters: fA, compare: false)).future);
    final futureB = container.read(eventsExplorerProvider((filters: fB, compare: false)).future);

    completerB.complete(http.Response(jsonEncode([
      const EventCount(day: '2026-10-03', eventName: 'event_b', count: 12).toJson(),
    ]), 200));

    final payloadB = await futureB;
    expect(payloadB.current.single.eventName, 'event_b');

    completerA.complete(http.Response(jsonEncode([
      const EventCount(day: '2026-10-01', eventName: 'event_a', count: 7).toJson(),
    ]), 200));

    final payloadA = await futureA;
    expect(payloadA.current.single.eventName, 'event_a');
  });

  test('changing baseUrlProvider invalidates days metadata and events provider', () async {
    final client1 = ApiClient('http://host1', client: MockClient((request) async {
      if (request.url.path == '/days') {
        return http.Response(jsonEncode([
          const DayStat(day: '2026-10-01', rowCount: 10, pulledAt: '2026-10-02T01:00:00Z').toJson(),
        ]), 200);
      }
      return http.Response(jsonEncode([
        const EventCount(day: '2026-10-01', eventName: 'host1_event', count: 10).toJson(),
      ]), 200);
    }));
    final client2 = ApiClient('http://host2', client: MockClient((request) async {
      if (request.url.path == '/days') {
        return http.Response(jsonEncode([
          const DayStat(day: '2026-10-02', rowCount: 20, pulledAt: '2026-10-03T01:00:00Z').toJson(),
        ]), 200);
      }
      return http.Response(jsonEncode([
        const EventCount(day: '2026-10-02', eventName: 'host2_event', count: 20).toJson(),
      ]), 200);
    }));
    addTearDown(client1.close);
    addTearDown(client2.close);

    final container = ProviderContainer(
      overrides: [
        baseUrlProvider.overrideWith(() => BaseUrlNotifier('http://host1')),
        apiClientProvider.overrideWith((ref) {
          final url = ref.watch(baseUrlProvider);
          return url == 'http://host1' ? client1 : client2;
        }),
      ],
    );
    addTearDown(container.dispose);

    const f = Filters(from: '2026-10-01', to: '2026-10-04');
    final p1 = await container.read(eventsExplorerProvider((filters: f, compare: false)).future);
    expect(p1.current.single.eventName, 'host1_event');
    expect(p1.days.single.rowCount, 10);

    // Invalidate baseUrlProvider
    container.read(baseUrlProvider.notifier).set('http://host2');

    final p2 = await container.read(eventsExplorerProvider((filters: f, compare: false)).future);
    expect(p2.current.single.eventName, 'host2_event');
    expect(p2.days.single.rowCount, 20);
  });
}
