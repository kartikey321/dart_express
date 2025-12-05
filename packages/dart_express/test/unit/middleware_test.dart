import 'dart:io';

import 'package:dart_express/dart_express.dart';
import 'package:test/test.dart';

import '../helpers/test_server_harness.dart';

void main() {
  group('Middleware pipeline', () {
    late TestServerHarness harness;

    setUp(() => harness = TestServerHarness());
    tearDown(() => harness.dispose());

    test('executes global middleware before route middleware', () async {
      final execution = <String>[];

      harness.app.use((req, res, next) async {
        execution.add('global');
        await next();
      });

      harness.app.get(
        '/ordered',
        (req, res) {
          execution.add('handler');
          res.text('done');
        },
        middleware: [
          (req, res, next) async {
            execution.add('route');
            await next();
          },
        ],
      );

      final response = await harness.get('/ordered');

      expect(response.statusCode, 200);
      expect(execution, ['global', 'route', 'handler']);
    });

    test('CORS middleware allows configured origins', () async {
      harness.app.use(
        harness.app.cors(
          allowedOrigins: const ['https://example.com'],
          allowedMethods: const ['GET', 'OPTIONS'],
          allowCredentials: true,
        ),
      );

      harness.app.options('/cors', (req, res) {});

      final response = await harness.send(
        'OPTIONS',
        '/cors',
        headers: {
          'Origin': 'https://example.com',
          'Access-Control-Request-Method': 'GET',
        },
      );

      expect(response.statusCode, HttpStatus.noContent);
      expect(response.headers['access-control-allow-origin'],
          equals('https://example.com'));
      expect(response.headers['access-control-allow-credentials'], 'true');
    });

    test('CORS middleware rejects disallowed origins', () async {
      harness.app.use(
        harness.app.cors(
          allowedOrigins: const ['https://allowed.com'],
        ),
      );
      harness.app.get('/cors', (req, res) => res.text('ok'));

      final response = await harness.get(
        '/cors',
        headers: {'Origin': 'https://blocked.com'},
      );

      expect(response.statusCode, HttpStatus.forbidden);
      expect(response.body, contains('CORS policy'));
    });

    test('CORS throws when allowCredentials with wildcard origins', () {
      expect(
        () => harness.app.cors(allowCredentials: true),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rate limiter returns 429 when limit exceeded', () async {
      final store = MemoryRateLimitStore();
      harness.app.use(
        harness.app.rateLimiter(
          maxRequests: 2,
          window: const Duration(seconds: 1),
          store: store,
        ),
      );
      harness.app.get('/limited', (req, res) => res.text('ok'));

      final first = await harness.get('/limited');
      final second = await harness.get('/limited');
      final third = await harness.get('/limited');

      expect(first.statusCode, 200);
      expect(second.statusCode, 200);
      expect(third.statusCode, HttpStatus.tooManyRequests);
      expect(third.body, contains('Rate limit exceeded'));

      store.dispose();
    });
  });
}
