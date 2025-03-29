import 'dart:io';

import 'package:dart_express/dart_express.dart';
import 'package:dart_express/src/middleware/cookies_parser.dart';

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

class DartExpress extends BaseContainer {
  DartExpress({
    bool useCookieParser = true,
    super.container,
    super.router,
  }) {
    if (useCookieParser) {
      use(CookieParser.middleware());
    }
  }

  void useController(String prefix, Controller controller) {
    controller.initialize(this, prefix: prefix);
  }

  void get(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.GET, path, handler, middleware: middleware);
  }

  void post(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.POST, path, handler, middleware: middleware);
  }

  void put(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.PUT, path, handler, middleware: middleware);
  }

  void patch(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.PATCH, path, handler, middleware: middleware);
  }

  void delete(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.DELETE, path, handler, middleware: middleware);
  }

  void options(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.OPTIONS, path, handler, middleware: middleware);
  }

  Future<void> listen(int port) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('Server listening on port ${server.port}');
    await for (HttpRequest httpRequest in server) {
      await handleRequest(httpRequest);
    }
  }

  MiddlewareHandler cors({
    List<String> allowedOrigins = const ['*'],
    List<String> allowedMethods = RequestTypes.allTypes,
    List<String> allowedHeaders = const ['Content-Type', 'Authorization'],
    bool allowCredentials = false,
    int maxAge = 86400,
  }) {
    return (request, response, next) async {
      final origin = request.headers.value('Origin');
      final method = request.method;

      // Check if the origin is allowed
      bool isAllowedOrigin(String? origin) {
        return origin != null &&
            (allowedOrigins.contains('*') || allowedOrigins.contains(origin));
      }

      if (isAllowedOrigin(origin)) {
        // Set CORS headers
        response.setHeader('Access-Control-Allow-Origin', origin!);
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
          response.setStatus(HttpStatus.noContent); // 204 No Content
          response.send(request.httpRequest.response);
          return;
        }
      } else if (origin != null && !isAllowedOrigin(origin)) {
        // If origin is not allowed, log and respond with 403 Forbidden
        print('CORS Denied - Origin not allowed: $origin');
        response.setStatus(HttpStatus.forbidden);
        response.text('CORS policy does not allow this origin.');
        response.send(request.httpRequest.response);
        return;
      } else if (!allowedMethods.contains(method)) {
        // If method is not allowed, respond with 405 Method Not Allowed
        print('CORS Denied - Method not allowed: $method');
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
}
