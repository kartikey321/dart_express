import 'dart:io';
import 'package:dart_express/dart_express.dart';
import 'package:uuid/uuid.dart';

/// Simple in-memory TODO REST API
///
/// Demonstrates:
/// - RESTful routing
/// - JSON responses
/// - Error handling
/// - CORS
/// - Basic validation
void main() async {
  final app = DartExpress(
    sessionSecret: 'dev-secret-for-demo-only-min-32-chars',
    secureCookies: false, // Dev mode
  );

  // In-memory store
  final todos = <String, Todo>{};
  final uuid = const Uuid();

  // CORS for API
  app.use(app.cors(
    allowedOrigins: ['*'], // Dev only - restrict in production
    allowedMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  ));

  // Logging
  app.use((req, res, next) async {
    print('[${DateTime.now()}] ${req.method} ${req.uri.path}');
    await next();
  });

  // === Routes ===

  // GET /todos - List all
  app.get('/todos', (req, res) {
    res.json({
      'todos': todos.values.map((t) => t.toJson()).toList(),
      'count': todos.length,
    });
  });

  // POST /todos - Create
  app.post('/todos', (req, res) async {
    final body = await req.json();

    if (body['title'] == null || body['title'].toString().trim().isEmpty) {
      return res.json(
        {'error': 'Title is required'},
        statusCode: 400,
      );
    }

    final todo = Todo(
      id: uuid.v4(),
      title: body['title'].toString(),
      completed: body['completed'] as bool? ?? false,
    );

    todos[todo.id] = todo;

    res.json(todo.toJson(), statusCode: 201);
  });

  // GET /todos/:id - Get one
  app.get('/todos/:id', (req, res) {
    final id = req.params['id']!;
    final todo = todos[id];

    if (todo == null) {
      return res.json({'error': 'Todo not found'}, statusCode: 404);
    }

    res.json(todo.toJson());
  });

  // PUT /todos/:id - Update
  app.put('/todos/:id', (req, res) async {
    final id = req.params['id']!;
    final todo = todos[id];

    if (todo == null) {
      return res.json({'error': 'Todo not found'}, statusCode: 404);
    }

    final body = await req.json();

    final updated = Todo(
      id: todo.id,
      title: body['title']?.toString() ?? todo.title,
      completed: body['completed'] as bool? ?? todo.completed,
    );

    todos[id] = updated;
    res.json(updated.toJson());
  });

  // DELETE /todos/:id - Delete
  app.delete('/todos/:id', (req, res) {
    final id = req.params['id']!;
    final removed = todos.remove(id);

    if (removed == null) {
      return res.json({'error': 'Todo not found'}, statusCode: 404);
    }

    res.json({'message': 'Todo deleted', 'id': id});
  });

  // Error handler
  app.setErrorHandler((error, req, res) async {
    print('Error: $error');
    res.json({'error': error.toString()}, statusCode: 500);
  });

  // Health check
  app.enableHealthCheck();

  // Start
  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  await app.listen(port);

  print('🚀 TODO API running on http://localhost:$port\n');
  print('Endpoints:');
  print('  GET    /todos     - List all todos');
  print('  POST   /todos     - Create todo');
  print('  GET    /todos/:id - Get todo');
  print('  PUT    /todos/:id - Update todo');
  print('  DELETE /todos/:id - Delete todo');
  print('  GET    /health    - Health check\n');
}

class Todo {
  final String id;
  final String title;
  final bool completed;

  Todo({required this.id, required this.title, required this.completed});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
      };
}
