import 'dart:io';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:dart_express/dart_express.dart';

/// Benchmarks routing performance with different route patterns
class RoutingBenchmark extends BenchmarkBase {
  late DartExpress app;
  late HttpServer server;
  late HttpClient client;
  final int routeCount;

  RoutingBenchmark(this.routeCount) : super('Routing-${routeCount}routes');

  @override
  void setup() {
    app = DartExpress();

    // Register multiple routes
    for (var i = 0; i < routeCount; i++) {
      app.get('/route$i', (req, res) {
        res.json({'id': i});
      });
    }

    // Add parameterized routes
    app.get('/users/:id', (req, res) {
      res.json({'userId': req.params['id']});
    });

    app.get('/posts/:postId/comments/:commentId', (req, res) {
      res.json({
        'postId': req.params['postId'],
        'commentId': req.params['commentId'],
      });
    });

    // Start server
    HttpServer.bind('localhost', 0).then((s) {
      server = s;
      server.listen(app.handleRequest);
    });

    client = HttpClient();
  }

  @override
  void run() {
    // Benchmark finding and executing a route
    final futures = <Future>[];

    // Test simple routes
    futures.add(_makeRequest('/route${routeCount ~/ 2}'));

    // Test parameterized routes
    futures.add(_makeRequest('/users/123'));
    futures.add(_makeRequest('/posts/456/comments/789'));

    Future.wait(futures);
  }

  Future<void> _makeRequest(String path) async {
    final request = await client.get('localhost', server.port, path);
    final response = await request.close();
    await response.drain();
  }

  @override
  void teardown() {
    client.close();
    server.close();
  }
}

/// Benchmarks middleware execution overhead
class MiddlewareBenchmark extends BenchmarkBase {
  late DartExpress app;
  late HttpServer server;
  late HttpClient client;
  final int middlewareCount;

  MiddlewareBenchmark(this.middlewareCount)
      : super('Middleware-${middlewareCount}layers');

  @override
  void setup() {
    app = DartExpress();

    // Add multiple middleware layers
    for (var i = 0; i < middlewareCount; i++) {
      app.use((req, res, next) async {
        req.session['middleware$i'] = true;
        await next();
      });
    }

    app.get('/test', (req, res) {
      res.json({'ok': true});
    });

    HttpServer.bind('localhost', 0).then((s) {
      server = s;
      server.listen(app.handleRequest);
    });

    client = HttpClient();
  }

  @override
  void run() {
    _makeRequest('/test');
  }

  Future<void> _makeRequest(String path) async {
    final request = await client.get('localhost', server.port, path);
    final response = await request.close();
    await response.drain();
  }

  @override
  void teardown() {
    client.close();
    server.close();
  }
}

/// Benchmarks session operations
class SessionBenchmark extends BenchmarkBase {
  late DartExpress app;
  late HttpServer server;
  late HttpClient client;
  late String sessionCookie;

  SessionBenchmark() : super('Session-ReadWrite');

  @override
  void setup() {
    app = DartExpress(
      sessionSecret: 'benchmark-secret-key-min-32-chars',
      sessionStore: MemorySessionStore(),
      secureCookies: false,
    );

    app.get('/write', (req, res) {
      req.session['user'] = 'benchmark';
      req.session['timestamp'] = DateTime.now().toIso8601String();
      req.session['counter'] = (req.session['counter'] ?? 0) + 1;
      res.json({'written': true});
    });

    app.get('/read', (req, res) {
      final user = req.session['user'];
      final counter = req.session['counter'];
      res.json({'user': user, 'counter': counter});
    });

    HttpServer.bind('localhost', 0).then((s) async {
      server = s;
      server.listen(app.handleRequest);

      // Initialize session
      final initReq = await client.get('localhost', server.port, '/write');
      final initRes = await initReq.close();
      sessionCookie = initRes.cookies.first.toString();
      await initRes.drain();
    });

    client = HttpClient();
  }

  @override
  void run() {
    _makeRequest('/write');
  }

  Future<void> _makeRequest(String path) async {
    final request = await client.get('localhost', server.port, path);
    request.headers.add('Cookie', sessionCookie);
    final response = await request.close();
    await response.drain();
  }

  @override
  void teardown() {
    client.close();
    server.close();
  }
}

/// Benchmarks JSON request/response handling
class JsonBenchmark extends BenchmarkBase {
  late DartExpress app;
  late HttpServer server;
  late HttpClient client;

  JsonBenchmark() : super('JSON-ParseStringify');

  @override
  void setup() {
    app = DartExpress();

    app.post('/echo', (req, res) async {
      final body = await req.body;
      res.json(body as Map<String, dynamic>);
    });

    HttpServer.bind('localhost', 0).then((s) {
      server = s;
      server.listen(app.handleRequest);
    });

    client = HttpClient();
  }

  @override
  void run() {
    _makeRequest();
  }

  Future<void> _makeRequest() async {
    final request = await client.post('localhost', server.port, '/echo');
    request.headers.contentType = ContentType.json;
    request.write('{"name":"benchmark","value":123,"nested":{"key":"value"}}');
    final response = await request.close();
    await response.drain();
  }

  @override
  void teardown() {
    client.close();
    server.close();
  }
}

void main() async {
  print('Dart Express Framework Benchmarks\n');
  print('=' * 60);

  // Routing benchmarks
  print('\n🔀 Routing Performance:');
  RoutingBenchmark(10).report();
  RoutingBenchmark(50).report();
  RoutingBenchmark(100).report();

  // Middleware benchmarks
  print('\n⚙️  Middleware Performance:');
  MiddlewareBenchmark(1).report();
  MiddlewareBenchmark(5).report();
  MiddlewareBenchmark(10).report();

  // Session benchmarks
  print('\n🔐 Session Performance:');
  SessionBenchmark().report();

  // JSON benchmarks
  print('\n📦 JSON Performance:');
  JsonBenchmark().report();

  print('\n' + '=' * 60);
  print('Benchmarks complete!');
}
