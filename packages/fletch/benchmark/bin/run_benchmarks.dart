import 'dart:io';
import 'package:fletch/fletch.dart';

/// Simple benchmarking utilities
class Benchmark {
  final String name;
  final Future<void> Function() fn;
  final int iterations;

  Benchmark(this.name, this.fn, {this.iterations = 1000});

  Future<void> run() async {
    // Warmup
    for (var i = 0; i < 10; i++) {
      await fn();
    }

    // Actual benchmark
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await fn();
    }
    stopwatch.stop();

    final avgMicros = stopwatch.elapsedMicroseconds / iterations;
    print('$name: ${avgMicros.toStringAsFixed(2)} μs/op');
  }
}

void main() async {
  print('Dart Express Framework Benchmarks\n');
  print('=' * 60);

  await benchmarkRouting();
  await benchmarkMiddleware();
  await benchmarkSessions();
  await benchmarkJson();

  print('\n${'=' * 60}');
  print('Benchmarks complete!');
  exit(0);
}

Future<void> benchmarkRouting() async {
  print('\n🔀 Routing Performance:');

  for (final routeCount in [10, 50, 100]) {
    final app = Fletch();

    // Register routes
    for (var i = 0; i < routeCount; i++) {
      app.get('/route$i', (req, res) => res.json({'id': i}));
    }
    app.get('/users/:id', (req, res) => res.json({'userId': req.params['id']}));

    final server = await app.listen(0);
    final client = HttpClient();

    await Benchmark(
      'Routing-${routeCount}routes',
      () async {
        final req = await client.get('localhost', server.port, '/users/123');
        final res = await req.close();
        await res.drain();
      },
      iterations: 100,
    ).run();

    client.close();
    await server.close();
  }
}

Future<void> benchmarkMiddleware() async {
  print('\n⚙️  Middleware Performance:');

  for (final middlewareCount in [1, 5, 10]) {
    final app = Fletch();

    // Add middleware layers
    for (var i = 0; i < middlewareCount; i++) {
      app.use((req, res, next) async {
        req.session['mw$i'] = true;
        await next();
      });
    }
    app.get('/test', (req, res) => res.json({'ok': true}));

    final server = await app.listen(0);
    final client = HttpClient();

    await Benchmark(
      'Middleware-${middlewareCount}layers',
      () async {
        final req = await client.get('localhost', server.port, '/test');
        final res = await req.close();
        await res.drain();
      },
      iterations: 100,
    ).run();

    client.close();
    await server.close();
  }
}

Future<void> benchmarkSessions() async {
  print('\n🔐 Session Performance:');

  final app = Fletch(
    sessionSecret: 'benchmark-secret-key-min-32-chars',
    sessionStore: MemorySessionStore(),
    secureCookies: false,
  );

  app.get('/write', (req, res) {
    req.session['user'] = 'benchmark';
    req.session['counter'] = (req.session['counter'] ?? 0) + 1;
    res.json({'written': true});
  });

  final server = await app.listen(0);
  final client = HttpClient();

  // Get session cookie
  final initReq = await client.get('localhost', server.port, '/write');
  final initRes = await initReq.close();
  final sessionCookie = initRes.cookies.first.toString();
  await initRes.drain();

  await Benchmark(
    'Session-ReadWrite',
    () async {
      final req = await client.get('localhost', server.port, '/write');
      req.headers.add('Cookie', sessionCookie);
      final res = await req.close();
      await res.drain();
    },
    iterations: 100,
  ).run();

  client.close();
  await server.close();
}

Future<void> benchmarkJson() async {
  print('\n📦 JSON Performance:');

  final app = Fletch();
  app.post('/echo', (req, res) async {
    final body = await req.body;
    res.json(body as Map<String, dynamic>);
  });

  final server = await app.listen(0);
  final client = HttpClient();

  await Benchmark(
    'JSON-ParseStringify',
    () async {
      final req = await client.post('localhost', server.port, '/echo');
      req.headers.contentType = ContentType.json;
      req.write('{"name":"test","value":123,"nested":{"key":"value"}}');
      final res = await req.close();
      await res.drain();
    },
    iterations: 100,
  ).run();

  client.close();
  await server.close();
}
