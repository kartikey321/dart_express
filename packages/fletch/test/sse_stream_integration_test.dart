import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:fletch/fletch.dart';

void main() {
  late Fletch app;
  HttpServer? server;
  int testPort = 0; // Will be assigned dynamically

  setUp(() async {
    app = Fletch();
  });

  tearDown(() async {
    if (server != null) {
      await server!.close(force: true);
      server = null;
      // Give the OS time to release the port
      await Future.delayed(Duration(milliseconds: 100));
    }
  });

  group('SSE Tests', () {
    test('basic SSE event delivery', () async {
      app.get('/sse', (req, res) async {
        await res.sse((sink) async {
          await sink.sendEvent('event1');
          await sink.sendEvent('event2');
          await sink.sendEvent('event3');
          sink.close();
        });
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request =
          await client.getUrl(Uri.parse('http://localhost:$testPort/sse'));
      request.headers.set('Accept', 'text/event-stream');
      final response = await request.close();

      expect(response.statusCode, equals(200));
      expect(
          response.headers.contentType?.mimeType, equals('text/event-stream'));

      final data = await response.transform(utf8.decoder).join();

      expect(data, contains('data: event1'));
      expect(data, contains('data: event2'));
      expect(data, contains('data: event3'));

      client.close();
    });

    test('SSE with event types and IDs', () async {
      app.get('/sse-typed', (req, res) async {
        await res.sse((sink) async {
          await sink.sendEvent('notification data',
              event: 'notification', id: '1');
          await sink.sendEvent('update data', event: 'update', id: '2');
          sink.close();
        });
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/sse-typed'));
      request.headers.set('Accept', 'text/event-stream');
      final response = await request.close();

      final data = await response.transform(utf8.decoder).join();

      expect(data, contains('event: notification'));
      expect(data, contains('id: 1'));
      expect(data, contains('data: notification data'));
      expect(data, contains('event: update'));
      expect(data, contains('id: 2'));
      expect(data, contains('data: update data'));

      client.close();
    });

    test('SSE with keep-alive', () async {
      app.get('/sse-keepalive', (req, res) async {
        await res.sse(
          (sink) async {
            await sink.sendEvent('initial');
            await Future.delayed(Duration(milliseconds: 500));
            await sink.sendEvent('final');
            sink.close();
          },
          keepAlive: Duration(milliseconds: 100),
        );
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/sse-keepalive'));
      request.headers.set('Accept', 'text/event-stream');
      final response = await request.close();

      final data = await response.transform(utf8.decoder).join();

      expect(data, contains('data: initial'));
      expect(data, contains('data: final'));
      expect(data, contains(': keep-alive')); // Keep-alive comment

      client.close();
    });

    test('SSE headers are correct', () async {
      app.get('/sse-headers', (req, res) async {
        await res.sse((sink) async {
          await sink.sendEvent('test');
          sink.close();
        });
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/sse-headers'));
      request.headers.set('Accept', 'text/event-stream');
      final response = await request.close();

      expect(
          response.headers.contentType?.mimeType, equals('text/event-stream'));
      expect(response.headers.contentType?.charset, equals('utf-8'));
      expect(response.headers.value('cache-control'), equals('no-cache'));
      expect(response.headers.value('connection'), equals('keep-alive'));

      await response.drain();
      client.close();
    });

    test('SSE prevents double configuration', () async {
      app.get('/sse-double', (req, res) async {
        await res.sse((sink) async {
          await sink.sendEvent('first');
          sink.close();
        });

        // This should throw
        await expectLater(
          res.sse((sink) async {}),
          throwsA(isA<StateError>()),
        );
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/sse-double'));
      final response = await request.close();

      await response.drain();
      client.close();
    });

    test('SSE prevents mixing with body', () async {
      app.get('/sse-body-conflict', (req, res) async {
        res.json({'test': 'data'});

        await expectLater(
          res.sse((sink) async {}),
          throwsA(isA<StateError>()),
        );
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/sse-body-conflict'));
      final response = await request.close();

      await response.drain();
      client.close();
    });
  });

  group('Streaming Tests', () {
    test('basic stream delivery', () async {
      app.get('/stream', (req, res) async {
        final stream = Stream<List<int>>.fromIterable([
          'chunk1\n'.codeUnits,
          'chunk2\n'.codeUnits,
          'chunk3\n'.codeUnits,
        ]);

        await res.stream(stream, contentType: 'text/plain');
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request =
          await client.getUrl(Uri.parse('http://localhost:$testPort/stream'));
      final response = await request.close();

      expect(response.statusCode, equals(200));

      final data = await response.transform(utf8.decoder).join();
      expect(data, equals('chunk1\nchunk2\nchunk3\n'));

      client.close();
    });

    test('stream with flush per chunk', () async {
      app.get('/stream-flush', (req, res) async {
        final stream = Stream<List<int>>.periodic(
          Duration(milliseconds: 50),
          (count) => 'data$count\n'.codeUnits,
        ).take(3);

        await res.stream(stream,
            flushEachChunk: true, contentType: 'text/plain');
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/stream-flush'));
      final response = await request.close();

      final chunks = <String>[];
      await for (final chunk in response.transform(utf8.decoder)) {
        chunks.add(chunk);
      }

      expect(chunks.length, greaterThan(0));
      expect(chunks.join(''), contains('data0'));
      expect(chunks.join(''), contains('data1'));
      expect(chunks.join(''), contains('data2'));

      client.close();
    });

    test('stream headers are correct', () async {
      app.get('/stream-headers', (req, res) async {
        final stream = Stream<List<int>>.fromIterable([
          'test'.codeUnits,
        ]);

        await res.stream(stream, contentType: 'application/octet-stream');
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/stream-headers'));
      final response = await request.close();

      expect(response.headers.contentType?.mimeType,
          equals('application/octet-stream'));
      expect(response.headers.value('cache-control'), equals('no-cache'));

      await response.drain();
      client.close();
    });

    test('stream prevents double configuration', () async {
      app.get('/stream-double', (req, res) async {
        final stream1 = Stream<List<int>>.fromIterable([
          'test'.codeUnits,
        ]);

        await res.stream(stream1);

        final stream2 = Stream<List<int>>.fromIterable([
          'test2'.codeUnits,
        ]);

        await expectLater(
          res.stream(stream2),
          throwsA(isA<StateError>()),
        );
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/stream-double'));
      final response = await request.close();

      await response.drain();
      client.close();
    });

    test('stream prevents mixing with SSE', () async {
      app.get('/stream-sse-conflict', (req, res) async {
        await res.sse((sink) async {
          await sink.sendEvent('test');
          sink.close();
        });

        final stream = Stream<List<int>>.fromIterable([
          'test'.codeUnits,
        ]);

        await expectLater(
          res.stream(stream),
          throwsA(isA<StateError>()),
        );
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/stream-sse-conflict'));
      final response = await request.close();

      await response.drain();
      client.close();
    });

    test('stream prevents mixing with body', () async {
      app.get('/stream-body-conflict', (req, res) async {
        res.text('some text');

        final stream = Stream<List<int>>.fromIterable([
          'test'.codeUnits,
        ]);

        await expectLater(
          res.stream(stream),
          throwsA(isA<StateError>()),
        );
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/stream-body-conflict'));
      final response = await request.close();

      await response.drain();
      client.close();
    });
  });

  group('SSE and Stream Mutual Exclusion', () {
    test('SSE after stream throws error', () async {
      app.get('/stream-then-sse', (req, res) async {
        final stream = Stream<List<int>>.fromIterable([
          'test'.codeUnits,
        ]);

        await res.stream(stream);

        await expectLater(
          res.sse((sink) async {}),
          throwsA(isA<StateError>()),
        );
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/stream-then-sse'));
      final response = await request.close();

      await response.drain();
      client.close();
    });

    test('stream after SSE throws error', () async {
      app.get('/sse-then-stream', (req, res) async {
        await res.sse((sink) async {
          await sink.sendEvent('test');
          sink.close();
        });

        final stream = Stream<List<int>>.fromIterable([
          'test'.codeUnits,
        ]);

        await expectLater(
          res.stream(stream),
          throwsA(isA<StateError>()),
        );
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/sse-then-stream'));
      final response = await request.close();

      await response.drain();
      client.close();
    });
  });

  group('Error Handling', () {
    // Note: These tests are flaky when run together due to timing/race conditions
    // They pass individually but may fail in the full suite
    // Core SSE/streaming functionality is fully tested above
    test('SSE handles client disconnect gracefully', () async {
      var eventsSent = 0;

      app.get('/sse-disconnect', (req, res) async {
        eventsSent = 0; // Reset for this request
        await res.sse((sink) async {
          try {
            for (var i = 0; i < 100; i++) {
              await sink.sendEvent('event$i');
              eventsSent++;
              await Future.delayed(Duration(milliseconds: 10));
            }
          } catch (e) {
            // Client disconnected - this is expected
          }
        });
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/sse-disconnect'));
      final response = await request.close();

      // Read a few chunks then close
      await response.take(2).drain();
      client.close(force: true);

      // Give server time to detect disconnect
      await Future.delayed(Duration(milliseconds: 300));

      // Should have sent some events but not all 100
      expect(eventsSent, greaterThan(0));
      expect(eventsSent, lessThan(100));
    });

    test('stream handles errors gracefully', () async {
      app.get('/stream-error', (req, res) async {
        final stream = Stream<List<int>>.fromIterable([
          'chunk1\n'.codeUnits,
          'chunk2\n'.codeUnits,
        ]).asyncMap((chunk) async {
          if (chunk == 'chunk2\n'.codeUnits) {
            throw Exception('Stream error');
          }
          return chunk;
        });

        try {
          await res.stream(stream);
        } catch (e, stackTrace) {
          print(e);
          print(stackTrace);
          // Error is expected
        }
      });

      server = await app.listen(0); // Dynamic port
      testPort = server!.port;

      final client = HttpClient();
      final request = await client
          .getUrl(Uri.parse('http://localhost:$testPort/stream-error'));

      try {
        final response = await request.close();
        await response.drain();
      } catch (e, stackTrace) {
        print(e);
        print(stackTrace);
        // Error is expected
      }

      client.close();
    });
  });
}
