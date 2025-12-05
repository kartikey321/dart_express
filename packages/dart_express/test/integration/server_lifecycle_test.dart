import 'dart:async';

import 'package:dart_express/dart_express.dart';
import 'package:test/test.dart';

import '../helpers/test_server_harness.dart';

void main() {
  group('Server lifecycle', () {
    TestServerHarness? harness;

    tearDown(() => harness?.dispose());

    test('waits for in-flight requests on close', () async {
      final app = DartExpress(
        requestTimeout: const Duration(seconds: 2),
        shutdownTimeout: const Duration(seconds: 2),
      );
      harness = TestServerHarness(app: app);

      final completer = Completer<void>();
      harness!.app.get('/slow', (req, res) async {
        await completer.future;
        res.text('done');
      });

      final responseFuture = harness!.get('/slow');
      await Future.delayed(const Duration(milliseconds: 50));

      final closeFuture = harness!.app.close();

      completer.complete();

      final response = await responseFuture;
      await closeFuture;

      expect(response.statusCode, 200);
    });

    test('rejects new requests once shutdown starts', () async {
      final app = DartExpress(shutdownTimeout: const Duration(seconds: 1));
      harness = TestServerHarness(app: app);
      await harness!.start();

      final slowCompleter = Completer<void>();
      harness!.app.get('/slow', (req, res) async {
        await slowCompleter.future;
        res.text('slow');
      });
      harness!.app.get('/ok', (req, res) => res.text('ok'));

      final slowFuture = harness!.get('/slow');
      final shuttingDown = harness!.app.close();
      await Future.delayed(const Duration(milliseconds: 25));
      final response = await harness!.get('/ok');

      expect(response.statusCode, 503);
      expect(response.body, contains('shutting down'));

      slowCompleter.complete();
      await slowFuture;
      await shuttingDown;
    });
  });
}
