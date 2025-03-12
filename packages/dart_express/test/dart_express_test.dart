import 'dart:io';

import 'package:dart_express/dart_express.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('Application', () {
    late DartExpress app;
    late HttpServer server;
    int port = 8081;

    setUp(() => app = DartExpress());

    // tearDown(() async {
    //   await server.close(force: true);
    // });

    Future<void> startServer() async {
      await app.listen(8081);
      port = 8081;
    }

    test('GET / returns 200 with correct body', () async {
      app.get('/', (Request req, Response res) => res.text('Hello World!'));
      startServer();
      await Future.delayed(Duration(seconds: 1));
      final response = await http.get(Uri.parse('http://localhost:$port/'));
      expect(response.statusCode, 200);
      expect(response.body, 'Hello World!');
    });

    test('POST / returns 201 with JSON response', () async {
      app.post(
          '/',
          (Request req, Response res) =>
              res.json({'success': true}, statusCode: 201));
      startServer();
      await Future.delayed(Duration(seconds: 1));

      final response = await http.post(Uri.parse('http://localhost:$port/'));
      expect(response.statusCode, 201);
      expect(response.headers['content-type'], 'application/json');
      expect(response.body, '{"success":true}');
    });

    test('Unknown route returns 404', () async {
      startServer();
      await Future.delayed(Duration(seconds: 1));

      final response =
          await http.get(Uri.parse('http://localhost:$port/not_found'));
      expect(response.statusCode, 404);
    });
  });

  group('Middleware', () {
    late DartExpress app;
    late HttpServer server;
    late int port;

    setUp(() => app = DartExpress());
    // tearDown(() async => await server.close());

    test('Runs middleware in order', () async {
      final order = <int>[];
      int port = 8081;
      app.use((req, res, next) {
        order.add(1);
        next();
      });

      app.use((req, res, next) {
        order.add(2);
        next();
      });

      app.get('/middleware', (req, res) {
        order.add(3);
        res.text('OK');
      });

      app.listen(port);
      await Future.delayed(Duration(seconds: 1));

      final response =
          await http.get(Uri.parse('http://localhost:$port/middleware'));
      expect(response.statusCode, 200);
      expect(order, [1, 2, 3]);
    });

    test('Middleware can modify response', () async {
      int port = 8081;

      app.use((req, res, next) {
        res.headers['X-Custom-Header'] = '123';
        next();
      });

      app.get('/header', (req, res) => res.text('OK'));
      app.listen(port);
      await Future.delayed(Duration(seconds: 1));

      final response =
          await http.get(Uri.parse('http://localhost:$port/header'));
      expect(response.headers['x-custom-header'], '123');
    });
  });

  group('Error Handling', () {
    late DartExpress app;
    late HttpServer server;
    int port = 8081;

    setUp(() => app = DartExpress());

    // tearDown(() async => app.);

    test('Unhandled error returns 500', () async {
      app.get('/error', (req, res) => throw Exception('Test Error'));
      app.listen(port);
      await Future.delayed(Duration(seconds: 1));

      final response =
          await http.get(Uri.parse('http://localhost:$port/error'));
      expect(response.statusCode, 500);
    });
  });

  group('Route Parameters', () {
    late DartExpress app;
    late HttpServer server;
    int port = 8082;

    setUp(() => app = DartExpress());

    // tearDown(() async => await server.close());

    test('Parses route parameters', () async {
      app.get('/users/:id', (req, res) {
        res.text('User ID: ${req.params['id']}');
      });

      app.listen(port);
      await Future.delayed(Duration(seconds: 1));

      final response =
          await http.get(Uri.parse('http://localhost:$port/users/123'));
      expect(response.statusCode, 200);
      expect(response.body, 'User ID: 123');
    });
  });

  //Write more tests here

}
