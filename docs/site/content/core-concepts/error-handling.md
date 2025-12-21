# Error Handling

Handle errors gracefully and provide meaningful feedback to clients.

## Basic Error Handling

### Try-Catch in Routes

```dart
app.get('/user/:id', (req, res) async {
  try {
    final userId = req.params['id']!;
    final user = await database.getUser(userId);
    
    if (user == null) {
      return res.status(404).json({'error': 'User not found'});
    }
    
    res.json(user);
  } catch (e) {
    res.status(500).json({
      'error': 'Internal server error',
      'message': e.toString(),
    });
  }
});
```

## Global Error Handler

Catch all unhandled errors:

```dart
void main() async {
  final app = Fletch();
  
  // Your routes
  app.get('/', myHandler);
  
  // Global error handler (must be last)
  app.use((req, res, next) async {
    try {
      await next();
    } catch (e, stackTrace) {
      print('Error: $e');
      print(stackTrace);
      
      res.status(500).json({
        'error': 'Internal server error',
        'message': e.toString(),
      });
    }
  });
  
  await app.listen(3000);
}
```

## Custom Error Classes

Create typed errors:

```dart
class AppError implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;
  
  AppError(this.message, {this.statusCode = 500, this.details});
  
  @override
  String toString() => message;
}

class NotFoundError extends AppError {
  NotFoundError(String message) : super(message, statusCode: 404);
}

class ValidationError extends AppError {
  ValidationError(String message, Map<String, dynamic> details)
      : super(message, statusCode: 400, details: details);
}

class UnauthorizedError extends AppError {
  UnauthorizedError(String message) : super(message, statusCode: 401);
}
```

### Using Custom Errors

```dart
app.get('/user/:id', (req, res) async {
  final user = await database.getUser(req.params['id']!);
  
  if (user == null) {
    throw NotFoundError('User not found');
  }
  
  res.json(user);
});

// Error handler
app.use((req, res, next) async {
  try {
    await next();
  } catch (e) {
    if (e is AppError) {
      return res.status(e.statusCode).json({
        'error': e.message,
        if (e.details != null) 'details': e.details,
      });
    }
    
    // Unknown error
    res.status(500).json({'error': 'Internal server error'});
  }
});
```

## Validation Errors

Handle invalid input:

```dart
app.post('/user', (req, res) async {
  final body = await req.body;
  final errors = <String, String>{};
  
  if (body['email'] == null || !isValidEmail(body['email'])) {
    errors['email'] = 'Valid email required';
  }
  
  if (body['password'] == null || body['password'].length < 8) {
    errors['password'] = 'Password must be at least 8 characters';
  }
  
  if (errors.isNotEmpty) {
    throw ValidationError('Validation failed', errors);
  }
  
  // Process request...
});
```

## Async Error Handling

Properly handle async errors:

```dart
app.get('/data', (req, res) async {
  try {
    final data = await fetchFromAPI();
    res.json(data);
  } on TimeoutException {
    res.status(504).json({'error': 'Gateway timeout'});
  } on SocketException {
    res.status(503).json({'error': 'Service unavailable'});
  } catch (e) {
    res.status(500).json({'error': 'Internal server error'});
  }
});
```

## Error Response Format

### Development vs Production

```dart
app.use((req, res, next) async {
  try {
    await next();
  } catch (e, stackTrace) {
    final isDev = Platform.environment['ENV'] != 'production';
    
    res.status(500).json({
      'error': 'Internal server error',
      if (isDev) 'message': e.toString(),
      if (isDev) 'stack': stackTrace.toString(),
    });
  }
});
```

### Structured Errors

```dart
class ErrorResponse {
  final String error;
  final int statusCode;
  final String? message;
  final Map<String, dynamic>? details;
  final String timestamp;
  
  ErrorResponse({
    required this.error,
    required this.statusCode,
    this.message,
    this.details,
  }) : timestamp = DateTime.now().toIso8601String();
  
  Map<String, dynamic> toJson() => {
    'error': error,
    'statusCode': statusCode,
    if (message != null) 'message': message,
    if (details != null) 'details': details,
    'timestamp': timestamp,
  };
}

// Usage
res.status(400).json(ErrorResponse(
  error: 'Bad Request',
  statusCode: 400,
  message: 'Invalid email format',
  details: {'field': 'email'},
).toJson());
```

## HTTP Status Codes

Use appropriate status codes:

```dart
// 400 - Bad Request
res.status(400).json({'error': 'Invalid input'});

// 401 - Unauthorized  
res.status(401).json({'error': 'Authentication required'});

// 403 - Forbidden
res.status(403).json({'error': 'Access denied'});

// 404 - Not Found
res.status(404).json({'error': 'Resource not found'});

// 409 - Conflict
res.status(409).json({'error': 'Email already exists'});

// 422 - Unprocessable Entity
res.status(422).json({'error': 'Validation failed', 'details': errors});

// 500 - Internal Server Error
res.status(500).json({'error': 'Internal server error'});

// 503 - Service Unavailable
res.status(503).json({'error': 'Service temporarily unavailable'});
```

## Database Errors

Handle database-specific errors:

```dart
app.post('/user', (req, res) async {
  try {
    final user = await database.createUser(data);
    res.status(201).json(user);
  } on DuplicateKeyException {
    res.status(409).json({'error': 'Email already exists'});
  } on DatabaseException catch (e) {
    print('Database error: $e');
    res.status(500).json({'error': 'Database error'});
  }
});
```

## Logging Errors

Log errors for debugging:

```dart
import 'package:logging/logging.dart';

final logger = Logger('MyApp');

app.use((req, res, next) async {
  try {
    await next();
  } catch (e, stackTrace) {
    logger.severe('Error processing request', e, stackTrace);
    
    res.status(500).json({
      'error': 'Internal server error',
      'requestId': generateRequestId(),
    });
  }
});
```

## Error Monitoring

Integrate with error tracking services:

```dart
app.use((req, res, next) async {
  try {
    await next();
  } catch (e, stackTrace) {
    // Send to Sentry, Bugsnag, etc.
    await errorTracker.captureException(e, stackTrace: stackTrace);
    
    res.status(500).json({'error': 'Internal server error'});
  }
});
```

## Rate Limit Errors

Handle rate limiting:

```dart
app.use(app.rateLimit(
  maxRequests: 100,
  windowMs: 60000,
  handler: (req, res) {
    res.status(429).json({
      'error': 'Too many requests',
      'retryAfter': 60,
    });
  },
));
```

## 404 Not Found

Handle routes that don't exist:

```dart
void main() async {
  final app = Fletch();
  
  // Your routes
  app.get('/users', getUserHandler);
  app.post('/users', createUserHandler);
  
  // 404 handler (must be after all routes)
  app.use((req, res, next) async {
    res.status(404).json({
      'error': 'Not Found',
      'path': req.uri.path,
    });
  });
  
  await app.listen(3000);
}
```

## Best Practices

1. **Always use try-catch** for async operations
2. **Return appropriate status codes**
3. **Don't expose stack traces** in production
4. **Log errors** for debugging
5. **Use typed errors** for better error handling
6. **Test error scenarios**
7. **Document error responses** in API docs

## Testing Errors

```dart
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('returns 404 for invalid route', () async {
    final response = await http.get(
      Uri.parse('http://localhost:3000/invalid'),
    );
    
    expect(response.statusCode, 404);
    expect(jsonDecode(response.body)['error'], 'Not Found');
  });
  
  test('returns 400 for invalid input', () async {
    final response = await http.post(
      Uri.parse('http://localhost:3000/user'),
      body: {'email': 'invalid'},
    );
    
    expect(response.statusCode, 400);
  });
}
```

<div style="display:flex;justify-content:space-between;gap:1rem;align-items:center;margin:2rem 0;">
  <a href="/core-concepts/sessions" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span aria-hidden="true">‹</span>
    <span>🔐 Sessions</span>
  </a>
  <a href="/deployment/docker" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span>🐳 Docker</span>
    <span aria-hidden="true">›</span>
  </a>
</div>
