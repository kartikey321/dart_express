import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

/// Tests for the TODO REST API example
///
/// Run the TODO API server before running these tests:
/// dart run bin/server.dart
void main() {
  final baseUrl = 'http://localhost:3000';
  late HttpClient client;

  setUp(() {
    client = HttpClient();
  });

  tearDown(() {
    client.close();
  });

  group('TODO API Tests', () {
    test('GET /todos returns empty list initially', () async {
      final request = await client.getUrl(Uri.parse('$baseUrl/todos'));
      final response = await request.close();

      expect(response.statusCode, equals(200));

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map;

      expect(data['todos'], isA<List>());
      expect(data['count'], isA<int>());
    });

    test('POST /todos creates a new todo', () async {
      final request = await client.postUrl(Uri.parse('$baseUrl/todos'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'title': 'Test Todo',
        'completed': false,
      }));

      final response = await request.close();
      expect(response.statusCode, equals(201));

      final body = await response.transform(utf8.decoder).join();
      final todo = jsonDecode(body) as Map;

      expect(todo['id'], isNotNull);
      expect(todo['title'], equals('Test Todo'));
      expect(todo['completed'], equals(false));
    });

    test('POST /todos requires title', () async {
      final request = await client.postUrl(Uri.parse('$baseUrl/todos'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'completed': false}));

      final response = await request.close();
      expect(response.statusCode, equals(400));

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map;

      expect(data['error'], contains('required'));
    });

    test('GET /todos/:id returns specific todo', () async {
      // Create a todo first
      var request = await client.postUrl(Uri.parse('$baseUrl/todos'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'title': 'Specific Todo'}));
      var response = await request.close();
      final createBody = await response.transform(utf8.decoder).join();
      final created = jsonDecode(createBody) as Map;
      final id = created['id'];

      // Get the specific todo
      request = await client.getUrl(Uri.parse('$baseUrl/todos/$id'));
      response = await request.close();

      expect(response.statusCode, equals(200));

      final body = await response.transform(utf8.decoder).join();
      final todo = jsonDecode(body) as Map;

      expect(todo['id'], equals(id));
      expect(todo['title'], equals('Specific Todo'));
    });

    test('GET /todos/:id returns 404 for non-existent todo', () async {
      final request = await client.getUrl(
        Uri.parse('$baseUrl/todos/non-existent-id'),
      );
      final response = await request.close();

      expect(response.statusCode, equals(404));

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map;

      expect(data['error'], contains('not found'));
    });

    test('PUT /todos/:id updates todo', () async {
      // Create a todo
      var request = await client.postUrl(Uri.parse('$baseUrl/todos'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'title': 'Original Title'}));
      var response = await request.close();
      final createBody = await response.transform(utf8.decoder).join();
      final created = jsonDecode(createBody) as Map;
      final id = created['id'];

      // Update the todo
      request = await client.putUrl(Uri.parse('$baseUrl/todos/$id'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'title': 'Updated Title',
        'completed': true,
      }));
      response = await request.close();

      expect(response.statusCode, equals(200));

      final body = await response.transform(utf8.decoder).join();
      final todo = jsonDecode(body) as Map;

      expect(todo['title'], equals('Updated Title'));
      expect(todo['completed'], equals(true));
    });

    test('DELETE /todos/:id removes todo', () async {
      // Create a todo
      var request = await client.postUrl(Uri.parse('$baseUrl/todos'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'title': 'To Delete'}));
      var response = await request.close();
      final createBody = await response.transform(utf8.decoder).join();
      final created = jsonDecode(createBody) as Map;
      final id = created['id'];

      // Delete the todo
      request = await client.deleteUrl(Uri.parse('$baseUrl/todos/$id'));
      response = await request.close();

      expect(response.statusCode, equals(200));

      final deleteBody = await response.transform(utf8.decoder).join();
      final deleteData = jsonDecode(deleteBody) as Map;

      expect(deleteData['message'], contains('deleted'));
      expect(deleteData['id'], equals(id));

      // Verify it's gone
      request = await client.getUrl(Uri.parse('$baseUrl/todos/$id'));
      response = await request.close();

      expect(response.statusCode, equals(404));
    });

    test('GET /health returns healthy status', () async {
      final request = await client.getUrl(Uri.parse('$baseUrl/health'));
      final response = await request.close();

      expect(response.statusCode, equals(200));

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map;

      expect(data['status'], equals('healthy'));
    });
  });
}
