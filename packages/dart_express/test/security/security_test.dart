import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_express/dart_express.dart';
import 'package:test/test.dart';

import '../helpers/test_server_harness.dart';

void main() {
  group('Security & robustness', () {
    TestServerHarness? harness;

    tearDown(() => harness?.dispose());

    test('times out hanging requests with 408', () async {
      final app = DartExpress(requestTimeout: const Duration(milliseconds: 75));
      harness = TestServerHarness(app: app);

      harness!.app.get('/hang', (req, res) async {
        await Completer<void>().future;
      });

      final response = await harness!.get('/hang');

      expect(response.statusCode, HttpStatus.requestTimeout);
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      expect(payload['error'], contains('Request Timeout'));
    });

    test('recovers after rejecting oversized payloads', () async {
      final app = DartExpress(maxBodySize: 512);
      harness = TestServerHarness(app: app);

      harness!.app
        ..post('/upload', (req, res) async {
          await req.body; // triggers size enforcement
          res.text('ok');
        })
        ..get('/health', (req, res) => res.text('ok'));

      final largeBody = List.filled(2048, 65);
      final rejection = await harness!.post(
        '/upload',
        body: largeBody,
        headers: {HttpHeaders.contentTypeHeader: 'application/octet-stream'},
      );
      final health = await harness!.get('/health');

      expect(rejection.statusCode, HttpStatus.requestEntityTooLarge);
      expect(jsonDecode(rejection.body), isA<Map>());
      expect(health.statusCode, HttpStatus.ok);
      expect(health.body, 'ok');
    });

    test('uses fallback error handler when custom handler fails', () async {
      harness = TestServerHarness();

      harness!.app.setErrorHandler((error, req, res) {
        throw StateError('broken handler');
      });

      harness!.app.get('/boom', (req, res) => throw Exception('boom'));

      final response = await harness!.get('/boom');

      expect(response.statusCode, HttpStatus.internalServerError);
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      expect(payload['error'], 'Internal Server Error');
    });
  });
}
