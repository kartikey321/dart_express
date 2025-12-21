import 'package:fletch/fletch.dart';
import 'package:test/test.dart';

void main() {
  group('RadixRouter matching', () {
    late RadixRouter router;

    setUp(() => router = RadixRouter());

    test('matches static routes first', () {
      void handler(Request _, Response __) {}
      router.addRoute('GET', '/users/list', handler);
      router.addRoute('GET', '/users/:id', (req, res) {});

      final match = router.findRoute('GET', '/users/list');
      expect(match, isNotNull);
      expect(match!.handler, same(handler));
    });

    test('extracts regex constrained parameters', () {
      router.addRoute('GET', '/users/:id(\\d+)', (req, res) {});
      final match = router.findRoute('GET', '/users/42');

      expect(match, isNotNull);
      expect(match!.pathParams['id'], '42');
    });

    test('skips non-matching regex segments', () {
      router.addRoute('GET', '/users/:id(\\d+)', (req, res) {});
      final match = router.findRoute('GET', '/users/abc');

      expect(match, isNull);
    });

    test('supports wildcard parameters', () {
      router.addRoute('GET', '/assets/:file', (req, res) {});
      final match = router.findRoute('GET', '/assets/logo.png');

      expect(match, isNotNull);
      expect(match!.pathParams['file'], 'logo.png');
    });

    test('throws on conflicting handlers', () {
      router.addRoute('GET', '/conflict', (req, res) {});
      expect(
        () => router.addRoute('GET', '/conflict', (req, res) {}),
        throwsA(isA<RouteConflictError>()),
      );
    });

    test('delegates to isolated routers at prefixes', () {
      final isolated = RadixRouter();
      void isolatedHandler(Request _, Response __) {}
      isolated.addRoute('GET', '/health', isolatedHandler);

      router.addIsolatedRouter('/api', isolated);

      final match = router.findRoute('GET', '/api/health');
      expect(match, isNotNull);
      expect(match!.handler, same(isolatedHandler));
    });
  });
}
