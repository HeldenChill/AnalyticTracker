import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _TrackingClient extends http.BaseClient {
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw UnimplementedError();
  @override
  void close() => closed = true;
}

void main() {
  test('close() closes the underlying http client', () {
    final inner = _TrackingClient();
    final api = ApiClient('http://host:8080', client: inner);
    api.close();
    expect(inner.closed, isTrue);
    expect(api.isClosed, isTrue);
  });

  test('changing server URL closes the previous ApiClient', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(apiClientProvider, (_, __) {});

    final first = container.read(apiClientProvider);
    container.read(baseUrlProvider.notifier).set('http://other:8080');
    final second = container.read(apiClientProvider);

    expect(identical(first, second), isFalse);
    expect(first.isClosed, isTrue);
    expect(second.isClosed, isFalse);
  });
}
