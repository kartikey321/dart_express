import 'dart:convert';
import 'dart:io';
import 'package:fletch/fletch.dart';
import 'package:test/test.dart';

void main() {
  group('Session Integration Tests', () {
    late Fletch app;
    late HttpServer server;
    const testSecret = 'integration-test-secret-key-min-32-chars';

    setUp(() async {
      app = Fletch(
        sessionSecret: testSecret,
        sessionStore: MemorySessionStore(),
        secureCookies: false, // For HTTP testing
      );

      // Test routes
      app.get('/set', (req, res) {
        req.session['userId'] = '123';
        req.session['username'] = 'testuser';
        res.json({'message': 'Session set'});
      });

      app.get('/get', (req, res) {
        final userId = req.session['userId'];
        final username = req.session['username'];
        res.json({'userId': userId, 'username': username});
      });

      app.get('/increment', (req, res) {
        final count = req.session['count'] ?? 0;
        req.session['count'] = count + 1;
        res.json({'count': req.session['count']});
      });

      app.get('/destroy', (req, res) async {
        await req.session.destroy();
        res.json({'message': 'Session destroyed'});
      });

      app.get('/clear', (req, res) {
        req.session.clear();
        res.json({'message': 'Session cleared'});
      });

      server = await app.listen(0); // Random available port
    });

    tearDown(() async {
      await server.close();
      await app.sessionStore?.dispose();
    });

    test('creates session on first request', () async {
      final client = HttpClient();
      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/set'));
      final response = await request.close();

      // Should receive a session cookie
      final cookies = response.cookies;
      expect(cookies, isNotEmpty);
      expect(cookies.any((c) => c.name == 'sessionId'), isTrue);

      await response.drain();
      client.close();
    });

    test('persists session data across requests', () async {
      final client = HttpClient();

      // First request: set session data
      var request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/set'));
      var response = await request.close();
      final sessionCookie =
          response.cookies.firstWhere((c) => c.name == 'sessionId');
      await response.drain();

      // Second request: get session data with cookie
      request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/get'));
      request.cookies.add(sessionCookie);
      response = await request.close();

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);

      expect(data['userId'], equals('123'));
      expect(data['username'], equals('testuser'));

      client.close();
    });

    test('session data is isolated between different sessions', () async {
      final client1 = HttpClient();
      final client2 = HttpClient();

      // Client 1: set session
      var request = await client1
          .getUrl(Uri.parse('http://localhost:${server.port}/set'));
      var response = await request.close();
      final cookie1 = response.cookies.firstWhere((c) => c.name == 'sessionId');
      print(cookie1);
      await response.drain();

      // Client 2: check session (no cookie)
      request = await client2
          .getUrl(Uri.parse('http://localhost:${server.port}/get'));
      response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);

      // Should get null/empty values (different session)
      expect(data['userId'], isNull);
      expect(data['username'], isNull);

      client1.close();
      client2.close();
    });

    test('session counter increments correctly', () async {
      final client = HttpClient();

      // Get session cookie
      var request = await client
          .getUrl(Uri.parse('http://localhost:${server.port}/increment'));
      var response = await request.close();
      final sessionCookie =
          response.cookies.firstWhere((c) => c.name == 'sessionId');
      var body = await response.transform(utf8.decoder).join();
      var data = jsonDecode(body);
      expect(data['count'], equals(1));

      // Increment again
      for (var i = 2; i <= 5; i++) {
        request = await client
            .getUrl(Uri.parse('http://localhost:${server.port}/increment'));
        request.cookies.add(sessionCookie);
        response = await request.close();
        body = await response.transform(utf8.decoder).join();
        data = jsonDecode(body);
        expect(data['count'], equals(i));
      }

      client.close();
    });

    test('session destroy removes session data', () async {
      final client = HttpClient();

      // Set session data
      var request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/set'));
      var response = await request.close();
      final sessionCookie =
          response.cookies.firstWhere((c) => c.name == 'sessionId');
      await response.drain();

      // Destroy session
      request = await client
          .getUrl(Uri.parse('http://localhost:${server.port}/destroy'));
      request.cookies.add(sessionCookie);
      response = await request.close();
      await response.drain();

      // Try to get session data with old cookie
      request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/get'));
      request.cookies.add(sessionCookie);
      response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);

      // Should be null (session destroyed)
      expect(data['userId'], isNull);
      expect(data['username'], isNull);

      client.close();
    });

    test('session clear removes all data but keeps session', () async {
      final client = HttpClient();

      // Set session data
      var request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/set'));
      var response = await request.close();
      final sessionCookie =
          response.cookies.firstWhere((c) => c.name == 'sessionId');
      await response.drain();

      // Clear session
      request = await client
          .getUrl(Uri.parse('http://localhost:${server.port}/clear'));
      request.cookies.add(sessionCookie);
      response = await request.close();
      await response.drain();

      // Try to get session data
      request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/get'));
      request.cookies.add(sessionCookie);
      response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);

      // Data should be cleared
      expect(data['userId'], isNull);
      expect(data['username'], isNull);

      // But can set new data with same session
      request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/set'));
      request.cookies.add(sessionCookie);
      response = await request.close();
      await response.drain();

      request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/get'));
      request.cookies.add(sessionCookie);
      response = await request.close();
      final body2 = await response.transform(utf8.decoder).join();
      final data2 = jsonDecode(body2);

      expect(data2['userId'], equals('123'));

      client.close();
    });

    test('signed session cookie prevents tampering', () async {
      final client = HttpClient();

      // Get valid session
      var request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/set'));
      var response = await request.close();
      final validCookie =
          response.cookies.firstWhere((c) => c.name == 'sessionId');
      await response.drain();

      // Tamper with cookie value
      final tamperedCookie =
          Cookie(validCookie.name, '${validCookie.value}tampered');

      // Try to use tampered cookie
      request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/get'));
      request.cookies.add(tamperedCookie);
      response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);

      // Should not get the session data (new session created)
      expect(data['userId'], isNull);

      client.close();
    });

    test('session without signature creates new session', () async {
      final client = HttpClient();

      // Create unsigned cookie
      final unsignedCookie = Cookie('sessionId', 'unsigned-session-id');

      // Try to use unsigned cookie
      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/get'));
      request.cookies.add(unsignedCookie);
      final response = await request.close();

      // Should create new session
      final newCookies = response.cookies;
      expect(newCookies.any((c) => c.name == 'sessionId'), isTrue);

      await response.drain();
      client.close();
    });
  });

  group('Session with External Store', () {
    late Fletch app;
    late HttpServer server;
    late MemorySessionStore store;

    setUp(() async {
      store = MemorySessionStore(defaultTTL: Duration(hours: 1));

      app = Fletch(
        sessionSecret: 'external-store-test-secret-32-chars',
        sessionStore: store,
        secureCookies: false,
      );

      app.get('/set/:key/:value', (req, res) {
        final key = req.params['key']!;
        final value = req.params['value']!;
        req.session[key] = value;
        res.json({'set': key});
      });

      app.get('/get/:key', (req, res) {
        final key = req.params['key']!;
        final value = req.session[key];
        res.json({'key': key, 'value': value});
      });

      server = await app.listen(0);
    });

    tearDown(() async {
      await server.close();
      await store.dispose();
    });

    test('session data persists in external store', () async {
      final client = HttpClient();

      // Set data
      var request = await client.getUrl(
        Uri.parse('http://localhost:${server.port}/set/name/Alice'),
      );
      var response = await request.close();
      final cookie = response.cookies.firstWhere((c) => c.name == 'sessionId');
      await response.drain();

      // Extract session ID from signed cookie
      final parts = cookie.value.split('.');
      final sessionId = parts[0];

      // Verify data is in store
      final storeData = await store.load(sessionId);
      expect(storeData, isNotNull);
      expect(storeData!['name'], equals('Alice'));

      client.close();
    });

    test('session changes are persisted', () async {
      final client = HttpClient();

      // Set initial value
      var request = await client.getUrl(
        Uri.parse('http://localhost:${server.port}/set/counter/1'),
      );
      var response = await request.close();
      final cookie = response.cookies.firstWhere((c) => c.name == 'sessionId');
      await response.drain();

      // Update value
      request = await client.getUrl(
        Uri.parse('http://localhost:${server.port}/set/counter/2'),
      );
      request.cookies.add(cookie);
      response = await request.close();
      await response.drain();

      // Verify updated value
      request = await client.getUrl(
        Uri.parse('http://localhost:${server.port}/get/counter'),
      );
      request.cookies.add(cookie);
      response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);

      expect(data['value'], equals('2'));

      client.close();
    });
  });
}
