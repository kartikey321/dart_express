import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_express/dart_express.dart';
import 'package:dart_express/src/middleware/cookies_parser.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import '../router/router_interface.dart';

/// Common HTTP method constants used across the framework.
class RequestTypes {
  static const String GET = 'GET';
  static const String POST = 'POST';
  static const String PUT = 'PUT';
  static const String PATCH = 'PATCH';
  static const String DELETE = 'DELETE';
  static const String OPTIONS = 'OPTIONS';

  static const List<String> allTypes = [GET, POST, PUT, PATCH, DELETE, OPTIONS];
}

/// DartExpress is a lightweight web framework for Dart, inspired by Express.js.
/// Provides routing helpers, middleware registration and server lifecycle
/// management around a standard [HttpServer].
class DartExpress extends BaseContainer {
  final int maxBodySize;
  final int maxFileSize;
  final Duration requestTimeout;
  final Duration shutdownTimeout;
  int _activeRequests = 0;
  bool _isShuttingDown = false;
  final DateTime _startTime = DateTime.now();

  DartExpress({
    bool useCookieParser = true,
    this.maxBodySize = 10 * 1024 * 1024, // 10MB
    this.maxFileSize = 100 * 1024 * 1024, // 100MB
    this.requestTimeout = const Duration(seconds: 30),
    this.shutdownTimeout = const Duration(seconds: 30),
    Logger? logger,
    RouterInterface? router,
    GetIt? container,
  }) : super(container: container, router: router, logger: logger) {
    _validateConfig();
    if (useCookieParser) {
      use(CookieParser.middleware());
    }
  }

  /// Mounts a controller under the provided [prefix]. Routes registered inside
  /// the controller will automatically inherit the prefix.
  void useController(String prefix, Controller controller) {
    controller.initialize(this, prefix: prefix);
  }

  /// Registers a `GET` handler at [path]. Optional [middleware] run after
  /// global middleware but before the handler executes.
  void get(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.GET, path, handler, middleware: middleware);
  }

  /// Registers a `POST` handler at [path]. Optional [middleware] run after
  /// global middleware but before the handler executes.
  void post(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.POST, path, handler, middleware: middleware);
  }

  /// Registers a `PUT` handler at [path]. Optional [middleware] run after
  /// global middleware but before the handler executes.
  void put(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.PUT, path, handler, middleware: middleware);
  }

  /// Registers a `PATCH` handler at [path]. Optional [middleware] run after
  /// global middleware but before the handler executes.
  void patch(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.PATCH, path, handler, middleware: middleware);
  }

  /// Registers a `DELETE` handler at [path]. Optional [middleware] run after
  /// global middleware but before the handler executes.
  void delete(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.DELETE, path, handler, middleware: middleware);
  }

  /// Registers an `OPTIONS` handler at [path]. Optional [middleware] run after
  /// global middleware but before the handler executes.
  void options(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.OPTIONS, path, handler, middleware: middleware);
  }

  final Map<HttpServer, Future<void>> _serverLifecycles = {};

  @override
  Future<void> handleRequest(HttpRequest httpRequest) async {
    final request = Request.from(
      httpRequest,
      container: container,
      maxBodySize: maxBodySize,
      maxFileSize: maxFileSize,
    );
    final response = Response();
    await processRequest(request, response);
  }

  /// Binds an [HttpServer] on the provided [port] (and optional [address]) and
  /// starts processing incoming requests in the background. The returned server
  /// can be closed by the caller when shutdown is required or during tests.
  Future<HttpServer> listen(
    int port, {
    InternetAddress? address,
    bool shared = false,
  }) async {
    address ??= InternetAddress.anyIPv4;
    final server = await HttpServer.bind(address, port, shared: shared);
    logger.i('Server listening on port ${server.port}');

    final lifecycle = _serve(server);
    _serverLifecycles[server] = lifecycle;
    lifecycle.whenComplete(() => _serverLifecycles.remove(server));

    return server;
  }

  /// Awaits the internal request-processing loop for [server], ensuring any
  /// teardown logic has completed once the server has been closed. Useful for
  /// integration tests where the server is created and disposed per test case.
  Future<void> waitUntilClosed(HttpServer server) async {
    final lifecycle = _serverLifecycles[server];
    if (lifecycle != null) {
      await lifecycle;
    }
  }

  /// Generates a CORS middleware using the provided allow lists. Handles
  /// pre-flight requests and applies common security headers.
  MiddlewareHandler cors({
    List<String> allowedOrigins = const ['*'],
    List<String> allowedMethods = RequestTypes.allTypes,
    List<String> allowedHeaders = const ['Content-Type', 'Authorization'],
    bool allowCredentials = false,
    int maxAge = 86400,
  }) {
    if (allowCredentials && allowedOrigins.contains('*')) {
      throw ArgumentError(
          'allowCredentials cannot be used with wildcard origins (*)');
    }

    return (request, response, next) async {
      final origin = request.headers.value('Origin');
      final method = request.method;

      // Check if the origin is allowed
      bool isAllowedOrigin(String? origin) {
        return origin != null &&
            (allowedOrigins.contains('*') || allowedOrigins.contains(origin));
      }

      final shouldEchoOrigin =
          allowedOrigins.isNotEmpty && !allowedOrigins.contains('*');

      if (shouldEchoOrigin && origin != null) {
        response.setHeader('Vary', 'Origin');
      }

      if (isAllowedOrigin(origin)) {
        // Set CORS headers
        final allowOriginHeader =
            allowedOrigins.contains('*') && !allowCredentials ? '*' : origin!;
        response.setHeader('Access-Control-Allow-Origin', allowOriginHeader);
        response.setHeader(
            'Access-Control-Allow-Methods', allowedMethods.join(', '));
        response.setHeader(
            'Access-Control-Allow-Headers', allowedHeaders.join(', '));
        response.setHeader('Access-Control-Max-Age', maxAge.toString());

        if (allowCredentials) {
          response.setHeader('Access-Control-Allow-Credentials', 'true');
        }

        // Handle preflight OPTIONS request
        if (method == 'OPTIONS') {
          response.setHeader('Vary',
              response.headers['Vary'] == null ? 'Origin' : response.headers['Vary']!);
          response.setHeader('Access-Control-Allow-Headers',
              request.headers.value('access-control-request-headers') ??
                  allowedHeaders.join(', '));
          response.setStatus(HttpStatus.noContent); // 204 No Content
          response.send(request.httpRequest.response);
          return;
        }
      } else if (origin != null && !isAllowedOrigin(origin)) {
        // If origin is not allowed, log and respond with 403 Forbidden
        logger.w('CORS denied - origin not allowed: $origin');
        response.setStatus(HttpStatus.forbidden);
        response.text('CORS policy does not allow this origin.');
        response.send(request.httpRequest.response);
        return;
      } else if (!allowedMethods.contains(method)) {
        // If method is not allowed, respond with 405 Method Not Allowed
        logger.w('CORS denied - method not allowed: $method');
        response.setStatus(HttpStatus.methodNotAllowed);
        response.text('Method not allowed.');
        response.send(request.httpRequest.response);
        return;
      }

      // Set additional security headers
      response.setHeader(
          'Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
      response.setHeader('X-Content-Type-Options', 'nosniff');
      response.setHeader('X-Frame-Options', 'DENY');

      await next();
    };
  }

  /// Builds a rate limiter middleware backed by [store] (or an in-memory
  /// default). Requests exceeding [maxRequests] within [window] receive a 429
  /// response. Customize [keyGenerator] to throttle by user/token/etc.
  MiddlewareHandler rateLimiter({
    int maxRequests = 100,
    Duration window = const Duration(minutes: 1),
    String Function(Request request)? keyGenerator,
    RateLimitStore? store,
  }) {
    final effectiveStore = store ?? MemoryRateLimitStore();
    return (request, response, next) async {
      final key = keyGenerator != null
          ? keyGenerator(request)
          : request.httpRequest.connectionInfo?.remoteAddress.address ??
              'unknown';

      final isAllowed =
          await effectiveStore.increment(key, maxRequests, window);

      if (!isAllowed) {
        response.setStatus(HttpStatus.tooManyRequests);
        response.text('Rate limit exceeded. Try again later.');
        return;
      }

      await next();
    };
  }

  /// Enable a simple health check endpoint at /health
  void enableHealthCheck() {
    get('/health', (req, res) {
      res.json({
        'status': 'ok',
        'uptime': DateTime.now().difference(_startTime).inSeconds,
        'activeRequests': _activeRequests,
      });
    });
  }

  /// Gracefully closes all servers, waiting for active requests to complete
  Future<void> close() async {
    _isShuttingDown = true;

    logger.i(
        'Graceful shutdown initiated. Waiting for $_activeRequests active requests...');

    final deadline = DateTime.now().add(shutdownTimeout);
    while (_activeRequests > 0 && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (_activeRequests > 0) {
      logger.w(
          'Forcefully closing with $_activeRequests active requests still in-flight');
    } else {
      logger.i('All requests completed. Closing servers.');
    }

    // Allow a short grace window for late-arriving requests to receive 503s
    await Future.delayed(const Duration(milliseconds: 50));

    for (final server in _serverLifecycles.keys.toList()) {
      final lifecycle = _serverLifecycles[server];
      await server.close(force: _activeRequests > 0);
      if (lifecycle != null) {
        await lifecycle;
      }
    }

    _serverLifecycles.clear();
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final httpRequest in server) {
        // Fire and forget - no blocking, trust Dart's event loop
        unawaited(_handleRequestWithTimeout(httpRequest));
      }
    } finally {
      await onDispose();
    }
  }

  Future<void> _handleRequestWithTimeout(HttpRequest httpRequest) async {
    // Reject new requests during shutdown
    if (_isShuttingDown) {
      httpRequest.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.add('Connection', 'close')
        ..write('Server is shutting down')
        ..close();
      return;
    }

    _activeRequests++;

    try {
      await handleRequest(httpRequest).timeout(
        requestTimeout,
        onTimeout: () => throw HttpError(408, 'Request Timeout'),
      );
    } catch (error, stackTrace) {
      await _safelySendErrorResponse(httpRequest, error, stackTrace);
    } finally {
      _activeRequests--;
    }
  }

  Future<void> _safelySendErrorResponse(
    HttpRequest httpRequest,
    dynamic error,
    StackTrace stackTrace,
  ) async {
    logger.e('Request error ${httpRequest.method} ${httpRequest.uri.path} '
        'reqId=${httpRequest.headers.value('x-request-id') ?? '-'}',
        error: error, stackTrace: stackTrace, time: DateTime.now());
    try {
      final statusCode = error is HttpError ? error.statusCode : 500;

      httpRequest.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': error.toString(),
          'statusCode': statusCode,
        }));

      await httpRequest.response.close();
    } catch (_) {
      // If we can't send error response, just try to close
      try {
        await httpRequest.response.close();
      } catch (_) {
        // Nothing more we can do
      }
    }
  }

  void _validateConfig() {
    if (maxBodySize <= 0) {
      throw ArgumentError('maxBodySize must be positive');
    }
    if (maxFileSize <= 0) {
      throw ArgumentError('maxFileSize must be positive');
    }
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError('requestTimeout must be positive');
    }
    if (shutdownTimeout <= Duration.zero) {
      throw ArgumentError('shutdownTimeout must be positive');
    }
    if (maxFileSize > maxBodySize) {
      logger.w(
          'maxFileSize ($maxFileSize) is greater than maxBodySize ($maxBodySize); large uploads may hit body limit first.');
    }
  }
}
