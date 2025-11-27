# dart_express Security & Production Readiness Fixes

**Philosophy**: Fast & Minimal. No artificial throttling - trust Dart's event loop. Fix real vulnerabilities, not theoretical ones.

---

## 🚨 CRITICAL - Must Fix Now

### 1. Memory Exhaustion - Unlimited Body Size

**Current:**
```dart
// lib/src/models/request.dart
Future<Uint8List> _ensureBodyBytes() async {
  final buffer = BytesBuilder();
  await for (final chunk in httpRequest) {
    buffer.add(chunk); // ❌ Attacker can OOM server
  }
  return buffer.takeBytes();
}
```

**Fix:**
```dart
final int _maxBodySize; // Pass from DartExpress constructor

Future<Uint8List> _ensureBodyBytes() async {
  final buffer = BytesBuilder();
  var totalSize = 0;

  await for (final chunk in httpRequest) {
    totalSize += chunk.length;
    if (totalSize > _maxBodySize) {
      await httpRequest.drain();
      throw HttpError(413, 'Payload Too Large');
    }
    buffer.add(chunk);
  }
  return buffer.takeBytes();
}
```

**Config:**
```dart
DartExpress({
  this.maxBodySize = 10 * 1024 * 1024, // 10MB default
});
```

---

### 2. Weak Session IDs - Predictable & Guessable

**Current:**
```dart
// Only 1000 possibilities per millisecond!
static String _generateSessionId() {
  return DateTime.now().millisecondsSinceEpoch.toString() +
      Random().nextInt(1000).toString();
}
```

**Fix:**
```dart
import 'package:uuid/uuid.dart';

static String _generateSessionId() {
  return const Uuid().v4(); // Cryptographically secure
}
```

**Add to pubspec.yaml:**
```yaml
dependencies:
  uuid: ^4.0.0
```

---

### 3. Error Handler Crashes Server

**Current:**
```dart
// lib/src/services/base_container.dart
if (_errorHandler != null) {
  await _errorHandler!(error, request, response); // ❌ Can crash
  return;
}
```

**Fix:**
```dart
if (_errorHandler != null) {
  try {
    await _errorHandler!(error, request, response);
    if (!response.isSent) {
      _sendDefaultError(error, response);
    }
    return;
  } catch (e, st) {
    print('Error handler failed: $e\n$st');
    // Fall through to default
  }
}
_sendDefaultError(error, response);
```

---

### 4. No Request Timeouts - Slowloris Attack

**Current:**
```dart
Future<void> _serve(HttpServer server) async {
  await for (final httpRequest in server) {
    await handleRequest(httpRequest); // ❌ Can hang forever
  }
}
```

**Fix:**
```dart
import 'package:async/async.dart';

final Duration requestTimeout;

Future<void> _serve(HttpServer server) async {
  await for (final httpRequest in server) {
    unawaited(_handleWithTimeout(httpRequest)); // ✅ Fire and forget
  }
}

Future<void> _handleWithTimeout(HttpRequest req) async {
  try {
    await handleRequest(req).timeout(
      requestTimeout,
      onTimeout: () => throw HttpError(408, 'Request Timeout'),
    );
  } catch (e, st) {
    _safelySendError(req, e);
  }
}

void _safelySendError(HttpRequest req, dynamic error) {
  try {
    if (!req.response.headersSent) {
      final status = error is HttpError ? error.statusCode : 500;
      req.response
        ..statusCode = status
        ..write(jsonEncode({'error': error.toString()}))
        ..close();
    }
  } catch (_) {
    try { req.response.close(); } catch (_) {}
  }
}
```

**Config:**
```dart
DartExpress({
  this.requestTimeout = const Duration(seconds: 30),
});
```

---

### 5. Sequential Request Processing - Kills Performance

**Current:**
```dart
await for (final httpRequest in server) {
  await handleRequest(httpRequest); // ❌ ONE AT A TIME
}
```

**Fix:** Already in #4 above with `unawaited()`

**Result:** 10-100x throughput improvement

---

## ⚠️ HIGH - Fix Before Production

### 6. File Uploads Buffer in Memory

**Current:**
```dart
await for (final part in transformer.bind(httpRequest)) {
  final bytes = await consolidateBytes(part); // ❌ Loads entire file
}
```

**Fix - Hybrid Approach:**
```dart
// Small files (< 1MB) stay in memory for speed
// Large files stream to disk

class MultipartFile {
  final String filename;
  final String? contentType;
  final Uint8List? bytes; // Small files
  final String? filePath; // Large files
  final int size;

  bool get isInMemory => bytes != null;

  Stream<List<int>> openRead() {
    if (bytes != null) return Stream.value(bytes!);
    return File(filePath!).openRead();
  }
}

Future<List<MultipartFile>> get files async {
  const memoryThreshold = 1024 * 1024; // 1MB
  final result = <MultipartFile>[];

  await for (final part in transformer.bind(httpRequest)) {
    // ... extract filename, contentType ...

    final chunks = <List<int>>[];
    var totalSize = 0;
    IOSink? fileSink;
    String? tempPath;

    await for (final chunk in part) {
      totalSize += chunk.length;

      if (totalSize > _maxFileSize) {
        await fileSink?.close();
        await File(tempPath!).delete().catchError((_) {});
        throw HttpError(413, 'File too large');
      }

      if (totalSize <= memoryThreshold) {
        chunks.add(chunk); // Keep in memory
      } else {
        // Switch to disk streaming
        if (fileSink == null) {
          tempPath = '/tmp/upload_${Uuid().v4()}';
          fileSink = File(tempPath).openWrite();
          for (final c in chunks) {
            fileSink.add(c); // Write buffered chunks
          }
          chunks.clear();
        }
        fileSink.add(chunk);
      }
    }

    await fileSink?.close();

    result.add(MultipartFile(
      filename: filename,
      contentType: contentType,
      bytes: fileSink == null ? Uint8List.fromList(chunks.expand((c) => c).toList()) : null,
      filePath: tempPath,
      size: totalSize,
    ));
  }

  return result;
}
```

---

### 7. No Graceful Shutdown - Drops Requests

**Fix:**
```dart
class DartExpress {
  int _activeRequests = 0;
  bool _isShuttingDown = false;
  final Duration shutdownTimeout;

  Future<void> _handleWithTimeout(HttpRequest req) async {
    if (_isShuttingDown) {
      req.response
        ..statusCode = 503
        ..write('Server shutting down')
        ..close();
      return;
    }

    _activeRequests++;
    try {
      await handleRequest(req).timeout(requestTimeout);
    } finally {
      _activeRequests--;
    }
  }

  Future<void> close() async {
    _isShuttingDown = true;

    final deadline = DateTime.now().add(shutdownTimeout);
    while (_activeRequests > 0 && DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(milliseconds: 100));
    }

    for (final lifecycle in _serverLifecycles.values) {
      await lifecycle.server.close(force: _activeRequests > 0);
    }
  }
}

// In main.dart - Handle SIGTERM
void main() async {
  final app = DartExpress();
  await app.listen(8080);

  ProcessSignal.sigterm.watch().listen((_) async {
    await app.close();
    exit(0);
  });

  await app.waitUntilClosed();
}
```

**Config:**
```dart
DartExpress({
  this.shutdownTimeout = const Duration(seconds: 30),
});
```

---

### 8. CORS - Basic But Correct

**Current CORS is too basic.** Fix it properly:

```dart
Middleware cors({
  List<String>? origins, // null = allow all
  List<String> methods = const ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  List<String> headers = const ['Content-Type', 'Authorization'],
}) {
  return (req, res, next) async {
    final origin = req.headers.value('origin');

    // Validate origin
    if (origins != null && !origins.contains(origin)) {
      res.statusCode = 403;
      res.json({'error': 'Origin not allowed'});
      return;
    }

    res.headers.add('Access-Control-Allow-Origin', origin ?? '*');

    // Handle preflight
    if (req.method == 'OPTIONS') {
      res.headers.add('Access-Control-Allow-Methods', methods.join(', '));
      res.headers.add('Access-Control-Allow-Headers', headers.join(', '));
      res.headers.add('Access-Control-Max-Age', '86400');
      res.statusCode = 204;
      res.send('');
      return;
    }

    await next();
  };
}
```

---

## 🟡 MEDIUM - Nice to Have

### 9. Simple Health Check

**Don't over-engineer.** Just add a basic endpoint:

```dart
// In DartExpress
void enableHealthCheck() {
  get('/health', (req, res) {
    res.json({
      'status': 'ok',
      'uptime': DateTime.now().difference(_startTime).inSeconds,
      'activeRequests': _activeRequests,
    });
  });
}
```

---

### 10. Request ID for Tracing

**Simple UUID per request:**

```dart
// In Request class
import 'package:uuid/uuid.dart';

late final String id;

Request.from(HttpRequest httpRequest, ...) {
  // ...
  id = httpRequest.headers.value('x-request-id') ?? Uuid().v4();
}

// Middleware
Middleware requestId() => (req, res, next) async {
  res.headers.add('X-Request-ID', req.id);
  await next();
};
```

---

### 11. Use Existing Logger Package

**DON'T write your own logger.** Use `package:logger`:

```dart
dependencies:
  logger: ^2.0.0
```

```dart
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

// Usage
logger.i('Server started on port 8080');
logger.e('Request failed', error: e, stackTrace: st);
```

---

### 12. Rate Limit Cleanup

**Fix memory leak:**

```dart
class MemoryRateLimitStore {
  final _store = <String, List<DateTime>>{};
  Timer? _cleanupTimer;

  MemoryRateLimitStore() {
    _cleanupTimer = Timer.periodic(Duration(minutes: 10), (_) => _cleanup());
  }

  void _cleanup() {
    final cutoff = DateTime.now().subtract(Duration(hours: 1));
    _store.removeWhere((_, timestamps) =>
      timestamps.isEmpty || timestamps.last.isBefore(cutoff)
    );
  }

  void dispose() => _cleanupTimer?.cancel();
}
```

---

## 🔧 SKIP - Not Worth It

### ❌ Route Conflict Detection
**Don't do this.** Just use first-match wins like Express.js. Users can handle route ordering.

### ❌ Custom Configuration Class
**Don't do this.** Just pass parameters to constructor. Keep it simple.

### ❌ Request-Scoped DI
**Don't do this.** Adds too much complexity. Use middleware to inject data.

### ❌ Response Compression
**Skip for now.** Most production setups use nginx/CDN for this.

---

## 🚨 MISSING - Critical Additions

### File Descriptor Limits

**Add ulimit awareness:**

```dart
// Check OS limits before going to production
void main() async {
  // On Linux: ulimit -n shows max FDs
  // Typical default: 1024
  // Set higher: ulimit -n 65536

  print('Note: Ensure ulimit -n is set appropriately for expected load');

  final app = DartExpress();
  await app.listen(8080);
}
```

**For production:** Set in systemd service or Docker:

```dockerfile
# Dockerfile
RUN ulimit -n 65536

# Or systemd
LimitNOFILE=65536
```

---

### Circuit Breaker for Downstream Services

**Add basic circuit breaker:**

```dart
class CircuitBreaker {
  int _failures = 0;
  DateTime? _openedAt;
  final int threshold;
  final Duration resetTimeout;

  CircuitBreaker({this.threshold = 5, this.resetTimeout = Duration(seconds: 60)});

  Future<T> execute<T>(Future<T> Function() fn) async {
    // Check if circuit is open
    if (_openedAt != null) {
      if (DateTime.now().difference(_openedAt!) < resetTimeout) {
        throw Exception('Circuit breaker is open');
      }
      _openedAt = null; // Try to close
      _failures = 0;
    }

    try {
      final result = await fn();
      _failures = 0; // Success resets counter
      return result;
    } catch (e) {
      _failures++;
      if (_failures >= threshold) {
        _openedAt = DateTime.now();
      }
      rethrow;
    }
  }
}

// Usage
final dbCircuit = CircuitBreaker();

app.get('/data', (req, res) async {
  try {
    final data = await dbCircuit.execute(() => db.query());
    res.json(data);
  } catch (e) {
    res.statusCode = 503;
    res.json({'error': 'Service unavailable'});
  }
});
```

---

## Implementation Plan

### Week 1: Critical Security
1. ✅ Body size limits
2. ✅ Secure session IDs (use uuid)
3. ✅ Error handler safety
4. ✅ Request timeouts + concurrent handling

### Week 2: Production Reliability
5. ✅ Graceful shutdown
6. ✅ File upload hybrid (memory/disk)
7. ✅ CORS fixes
8. ✅ Rate limit cleanup

### Week 3: Observability
9. ✅ Health check endpoint
10. ✅ Request IDs
11. ✅ Use logger package

### Later: Advanced
12. Circuit breakers for external deps
13. Load testing (aim for 10k+ req/s)

---

## Testing

**Load test to validate:**

```bash
# Use wrk or apache bench
wrk -t4 -c100 -d30s http://localhost:8080/health

# Expected results:
# - Before concurrent fix: ~100 req/s
# - After concurrent fix: 10,000+ req/s
# - Memory should stay bounded
# - No crashes under load
```

**Security test:**

```bash
# Try to OOM server with large body
curl -X POST http://localhost:8080/upload \
  -H "Content-Type: application/json" \
  -d @/dev/zero  # Should get 413 after 10MB
```

---

## Dependencies to Add

```yaml
dependencies:
  async: ^2.11.0      # For unawaited()
  uuid: ^4.0.0        # Secure session IDs
  logger: ^2.0.0      # Structured logging
```

---

## Configuration (Keep It Simple)

```dart
class DartExpress extends BaseContainer {
  final int maxBodySize;
  final int maxFileSize;
  final Duration requestTimeout;
  final Duration shutdownTimeout;

  DartExpress({
    this.maxBodySize = 10 * 1024 * 1024,        // 10MB
    this.maxFileSize = 100 * 1024 * 1024,       // 100MB
    this.requestTimeout = Duration(seconds: 30),
    this.shutdownTimeout = Duration(seconds: 30),
  });
}
```

**That's it.** Four config options. No configuration hell.

---

## Reality Checks

1. **Dart's event loop ≠ Node.js exactly** - Load test to verify assumptions
2. **File uploads** - Disk I/O can bottleneck, hybrid approach helps
3. **FD limits** - OS will hit limits before memory, be aware
4. **No magic** - Trust but verify with real load tests

**The goal: Fast, minimal, production-ready. Not over-engineered.**