# Routing

dart_express uses a fast radix-tree router to match incoming requests to handlers.

## Basic Routes

Define routes for different HTTP methods:

```dart
final app = DartExpress();

app.get('/users', (req, res) {
  res.json({'users': []});
});

app.post('/users', (req, res) async {
  final body = await req.body;
  res.status(201).json(body);
});

app.put('/users/:id', (req, res) {
  res.json({'updated': req.params['id']});
});

app.delete('/users/:id', (req, res) {
  res.status(204).send();
});
```

## Path Parameters

Capture dynamic segments from the URL:

```dart
app.get('/users/:userId/posts/:postId', (req, res) {
  final userId = req.params['userId'];
  final postId = req.params['postId'];
  
  res.json({
    'userId': userId,
    'postId': postId,
  });
});
```

Access via: `/users/123/posts/456`

## Query Parameters

Access query string parameters:

```dart
app.get('/search', (req, res) {
  final query = req.query['q'];
  final page = int.tryParse(req.query['page'] ?? '1') ?? 1;
  
  res.json({
    'query': query,
    'page': page,
    'results': [],
  });
});
```

Access via: `/search?q=dart&page=2`

## Wildcard Routes

Match multiple path segments:

```dart
app.get('/files/*', (req, res) {
  final filePath = req.params['*'];
  res.text('File path: $filePath');
});
```

Access `/files/documents/report.pdf` → captures `documents/report.pdf`

## Route Groups

Organize routes with common prefixes:

```dart
// API v1 routes
app.get('/api/v1/users', getUsersV1);
app.get('/api/v1/posts', getPostsV1);

// API v2 routes
app.get('/api/v2/users', getUsersV2);
app.get('/api/v2/posts', getPostsV2);
```

## Route Order

Routes are matched in the order they're defined:

```dart
// Specific route first
app.get('/users/me', (req, res) {
  res.json({'user': 'current user'});
});

// Generic route second
app.get('/users/:id', (req, res) {
  res.json({'user': req.params['id']});
});
```

## Controllers

Organize related routes in controllers:

```dart
class UserController {
  void getAll(Request req, Response res) {
    res.json({'users': []});
  }
  
  void getById(Request req, Response res) {
    res.json({'id': req.params['id']});
  }
  
  Future<void> create(Request req, Response res) async {
    final body = await req.body;
    res.status(201).json(body);
  }
}

void main() {
  final app = DartExpress();
  final users = UserController();
  
  app.get('/users', users.getAll);
  app.get('/users/:id', users.getById);
  app.post('/users', users.create);
}
```

## Method Chaining

Chain multiple route handlers:

```dart
app
  .get('/users', getAllUsers)
  .post('/users', createUser)
  .put('/users/:id', updateUser)
  .delete('/users/:id', deleteUser);
```

## All Methods

Handle any HTTP method:

```dart
app.all('/api/*', (req, res, next) async {
  print('API called: ${req.method} ${req.uri.path}');
  await next();
});
```

## Regular Expressions

For complex patterns, routes use glob syntax internally:

```dart
app.get('/users/:id', handler);        // :id matches any segment
app.get('/files/*', handler);          // * matches multiple segments
```

## Performance

The radix tree router provides:
- **O(log n) lookup time**
- **Efficient matching** even with thousands of routes
- **Zero allocations** for route matching

<div style="display:flex;justify-content:space-between;gap:1rem;align-items:center;margin:2rem 0;">
  <a href="/getting-started/quick-start" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span aria-hidden="true">‹</span>
    <span>🚀 Quick Start</span>
  </a>
  <a href="/core-concepts/middleware" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span>🧩 Middleware</span>
    <span aria-hidden="true">›</span>
  </a>
</div>
