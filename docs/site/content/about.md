# About dart_express

dart_express is a web framework for Dart inspired by Express.js, designed to make building HTTP servers simple, intuitive, and productive.

## Philosophy

### Simplicity First
dart_express follows the Express.js philosophy: provide a minimal, flexible framework that doesn't get in your way.

```dart
final app = DartExpress();
app.get('/', (req, res) => res.text('Simple!'));
await app.listen(3000);
```

### Middleware-Centric
Everything is a middleware. This makes the framework incredibly composable:

```dart
// Logging
app.use((req, res, next) async {
  print('${req.method} ${req.uri.path}');
  await next();
});

// CORS
app.use(app.cors());

// Routes
app.get('/api', handler);
```

### Type-Safe
Built on Dart, you get compile-time type safety:

```dart
app.post('/api/user', (req, res) async {
  final body = await req.body; // Map<String, dynamic>
  final name = body['name'] as String; // Type-checked
  res.json({'created': name});
});
```

## Architecture

### Request Pipeline

```
Request →  Middleware 1 →  Middleware 2 →  Route Handler →  Response
              ↓                ↓                ↓
           next()          next()           res.json()
```

Every request flows through:
1. **Global middleware** (CORS, logging, etc.)
2. **Route-specific middleware**
3. **Route handler**
4. **Response**

### Core Components

#### **DartExpress**
The main application class. Manages middleware, routing, and server lifecycle.

#### **Request**
Represents an HTTP request with helpers for:
- Path parameters: `req.params['id']`
- Query strings: `req.query['search']`
- Body parsing: `await req.body`
- Sessions: `req.session`
- Headers: `req.headers`

#### **Response**
Fluent API for building responses:
- `res.text('Hello')`
- `res.json({...})`
- `res.status(404)`
- `res.cookie('name', 'value')`

#### **Router**
Radix-tree based router for fast path matching with support for:
- Path parameters: `/users/:id`
- Wildcards: `/files/*`
- Method-based routing

## Key Features

### Sessions
Built-in session management with pluggable stores:

```dart
final app = DartExpress(
  sessionSecret: 'your-secret-key',
  sessionStore: MemorySessionStore(), // Default
);

app.get('/counter', (req, res) {
  final count = (req.session['count'] as int? ?? 0) + 1;
  req.session['count'] = count;
  res.json({'visits': count});
});
```

### CORS
One-line CORS configuration:

```dart
app.use(app.cors(
  allowedOrigins: ['https://example.com'],
  allowedMethods: ['GET', 'POST'],
  credentials: true,
));
```

### Rate Limiting
Protect your API from abuse:

```dart
app.use(app.rateLimit(
  maxRequests: 100,
  windowMs: 60000, // 1 minute
));
```

### Dependency Injection
Uses GetIt for service management:

```dart
final container = GetIt.instance;
container.registerSingleton(UserService());

app.get('/users', (req, res) {
  final userService = container<UserService>();
  res.json(userService.getAll());
});
```

## Performance

dart_express is designed for performance:

- **Radix Tree Router**: O(log n) route matching
- **Zero-copy Body Parsing**: Efficient request handling  
- **Async/Await**: Non-blocking I/O throughout
- **Isolate Support**: Scale across CPU cores

Run benchmarks:
```bash
cd packages/dart_express/benchmark
dart run bin/run_benchmarks.dart
```

## Comparison

| Feature | dart_express | Shelf | Aqueduct |
|---------|-------------|-------|----------|
| Express-like API | ✅ | ❌ | ❌ |
| Built-in Sessions | ✅ | ❌ | ✅ |
| Middleware Pipeline | ✅ | ✅ | ✅ |
| DI Container | ✅ (GetIt) | ❌ | ✅ |
| Active Development | ✅ | ✅ | ❌ (Discontinued) |

## Examples

Check out these complete examples:

- **TODO API** - Full REST API at `/apps/dart_express_examples/todo_api_example`
- **Session Auth** - Authentication demo at `/apps/dart_express_examples/session_security_example`
- **MongoDB** - Database integration at `/apps/dart_express_examples/mongo_example`

## Contributing

We welcome contributions! Check out our [GitHub repository](https://github.com/kartikey321/dart_express) to:

- Report bugs
- Suggest features
- Submit pull requests
- Improve documentation

## License

dart_express is open source software licensed under the MIT license.

---

Ready to build something? Check out the [GitHub repo](https://github.com/kartikey321/dart_express) to get started!
