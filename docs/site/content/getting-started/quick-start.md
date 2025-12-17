# Quick Start

Build your first dart_express application in 5 minutes.

## Basic Server

Create a simple HTTP server:

```dart
import 'package:dart_express/dart_express.dart';

void main() async {
  final app = DartExpress(
    // Use a strong secret for signed session cookies.
    sessionSecret: 'change-me-to-a-32+char-random-secret',
    // Set to false only for local HTTP development.
    secureCookies: true,
  );

  // Simple text response
  app.get('/', (req, res) {
    res.text('Welcome to dart_express!');
  });

  await app.listen(3000);
  print('Server running on http://localhost:3000');
}
```

## JSON API

Build a REST API endpoint:

```dart
app.get('/api/users', (req, res) {
  res.json({
    'users': [
      {'id': 1, 'name': 'Alice', 'email': 'alice@example.com'},
      {'id': 2, 'name': 'Bob', 'email': 'bob@example.com'},
    ],
  });
});
```

Test it:
```bash
curl http://localhost:3000/api/users
```

## Path Parameters

Handle dynamic routes:

```dart
app.get('/users/:id', (req, res) {
  final userId = req.params['id'];
  res.json({
    'userId': userId,
    'name': 'User $userId',
  });
});
```

Try it:
```bash
curl http://localhost:3000/users/123
# {"userId":"123","name":"User 123"}
```

## POST Requests

Handle form data:

```dart
app.post('/api/users', (req, res) async {
  final body = await req.body;
  final name = body['name'];
  
  res.status(201).json({
    'id': 3,
    'name': name,
    'created': DateTime.now().toIso8601String(),
  });
});
```

Test with curl:
```bash
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Charlie"}'
```

## Middleware

Add logging to all requests:

```dart
// Log every request
app.use((req, res, next) async {
  print('[${DateTime.now()}] ${req.method} ${req.uri.path}');
  await next();
});

// Your routes here
app.get('/', (req, res) => res.text('Hello!'));
```

## CORS

Enable CORS for your API:

```dart
app.use(app.cors(
  allowedOrigins: ['http://localhost:3000', 'https://myapp.com'],
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowCredentials: true,
));
```

## Sessions

Add user sessions:

```dart
final app = DartExpress(
  sessionSecret: 'your-secret-key-min-32-chars!',
);

app.get('/counter', (req, res) {
  final count = (req.session['count'] as int? ?? 0) + 1;
  req.session['count'] = count;
  
  res.json({'visits': count});
});
```

Each visitor gets tracked independently. For production, use a persistent `SessionStore` (e.g., Redis) so sessions survive restarts.

## Error Handling

Handle errors gracefully:

```dart
app.get('/error', (req, res) {
  throw Exception('Something went wrong!');
});

// Error handler middleware (must be last)
app.use((req, res, next) async {
  try {
    await next();
  } catch (e) {
    res.status(500).json({
      'error': e.toString(),
    });
  }
});
```

## Complete Example

A full-featured API server:

```dart
import 'package:dart_express/dart_express.dart';

void main() async {
  final app = DartExpress(
    sessionSecret: 'my-super-secret-key-min-32-chars',
  );

  // Middleware
  app.use((req, res, next) async {
    print('${req.method} ${req.uri.path}');
    await next();
  });

  app.use(app.cors());

  // Routes
  app.get('/', (req, res) {
    res.json({'message': 'Welcome to my API!'});
  });

  app.get('/users/:id', (req, res) {
    res.json({
      'id': req.params['id'],
      'name': 'User ${req.params['id']}',
    });
  });

  app.post('/users', (req, res) async {
    final body = await req.body;
    res.status(201).json({
      'created': body,
      'timestamp': DateTime.now().toIso8601String(),
    });
  });

  // Start server
  await app.listen(3000);
  print('🚀 API running on http://localhost:3000');
}
```

## Running in Production

For production use:

```dart
final app = DartExpress(
  sessionSecret: Platform.environment['SESSION_SECRET']!,
  secureCookies: true, // HTTPS only
);

final port = int.parse(Platform.environment['PORT'] ?? '3000');
await app.listen(port, host: '0.0.0.0');
```

<Warning>
Always use environment variables for secrets in production!
</Warning>

<div style="display:flex;justify-content:space-between;gap:1rem;align-items:center;margin:2rem 0;">
  <a href="/getting-started/installation" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span aria-hidden="true">‹</span>
    <span>🛠️ Installation</span>
  </a>
  <a href="/core-concepts/routing" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span>🧭 Routing</span>
    <span aria-hidden="true">›</span>
  </a>
</div>

<Tip>
Check out the TODO API example in `/apps/dart_express_examples/todo_api_example` for a complete REST API!
</Tip>
