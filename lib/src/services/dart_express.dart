import 'dart:io';

import 'package:dart_express/src/services/router.dart';

import '../models/memory_store.dart';
import '../models/middleware.dart';
import '../models/request.dart';
import '../models/response.dart';
import 'controller.dart';
import 'dependency_injection.dart';
import 'error_handler.dart';

class RequestTypes {
  static const String GET = 'GET';
  static const String POST = 'POST';
  static const String PUT = 'PUT';
  static const String PATCH = 'PATCH';
  static const String DELETE = 'DELETE';
  static const String OPTIONS = 'OPTIONS';

  static const List<String> allTypes = [GET, POST, PUT, PATCH, DELETE, OPTIONS];
}

class DartExpress {
  final Router _router = Router();
  final List<MiddlewareHandler> _globalMiddleware = [];
  final DIContainer _container = DIContainer();
  DIContainer get container => _container;
  ErrorHandler? _errorHandler;

  void setErrorHandler(ErrorHandler handler) {
    _errorHandler = handler;
  }

  void useController(String prefix, Controller controller) {
    controller.initialize(this, prefix: prefix);
  }

  void use(MiddlewareHandler middleware) {
    _globalMiddleware.add(middleware);
  }

  void get(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    _addRoute(RequestTypes.GET, path, handler, middleware: middleware);
  }

  void post(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    _addRoute(RequestTypes.POST, path, handler, middleware: middleware);
  }

  void put(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    _addRoute(RequestTypes.PUT, path, handler, middleware: middleware);
  }

  void patch(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    _addRoute(RequestTypes.PATCH, path, handler, middleware: middleware);
  }

  void delete(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    _addRoute(RequestTypes.DELETE, path, handler, middleware: middleware);
  }

  void options(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    _addRoute(RequestTypes.OPTIONS, path, handler, middleware: middleware);
  }

  void _addRoute(String method, String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    final wrappedHandler = _wrapWithMiddleware(handler, middleware ?? []);
    _router.addRoute(method, path, wrappedHandler);
  }

  RequestHandler _wrapWithMiddleware(
      RequestHandler handler, List<MiddlewareHandler> routeMiddleware) {
    return (Request request, Response response) async {
      int globalIndex = 0;
      int routeIndex = 0;

      Future<void> runNextMiddleware() async {
        if (globalIndex < _globalMiddleware.length) {
          await _globalMiddleware[globalIndex++](
              request, response, runNextMiddleware);
        } else if (routeIndex < routeMiddleware.length) {
          await routeMiddleware[routeIndex++](
              request, response, runNextMiddleware);
        } else {
          await handler(request, response);
        }
      }

      await runNextMiddleware();
    };
  }

  void inject<T>(T instance) {
    _container.registerSingleton<T>(instance);
  }

  Future<void> listen(int port) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('Server listening on port ${server.port}');

    await for (HttpRequest httpRequest in server) {
      await _handleRequest(httpRequest);
    }
  }

  Future<void> _handleRequest(HttpRequest httpRequest) async {
    final request = Request.from(httpRequest, container: _container);
    final response = Response();

    try {
      final handler = _router.findHandler(request.method, request.uri.path);
      if (handler != null) {
        await handler(request, response);
      } else {
        throw NotFoundError('Route not found: ${request.uri.path}');
      }
    } catch (error, stackTrace) {
      if (_errorHandler != null) {
        try {
          await _errorHandler!(error, request, response);
        } catch (e) {
          print('Error in error handler: $e');
          response.setStatus(HttpStatus.internalServerError);
          response.json({
            'error': 'Internal Server Error',
            'message': 'Error handling the original error'
          });
        }
      } else {
        print('Unhandled error: $error\nStackTrace: $stackTrace');
        if (error is HttpError) {
          response.setStatus(error.statusCode);
          response.json(
            {
              'error': error.message,
              'data': error.data,
            },
          );
        } else {
          response.setStatus(HttpStatus.internalServerError);
          response.json(
              {'error': 'Internal Server Error', 'message': error.toString()});
        }
      }
    }

    if (!response.isSent) {
      response.send(httpRequest.response);
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
        response.setStatus(HttpStatus.forbidden); // 403 Forbidden
        response.text('CORS policy does not allow this origin.');
        response.send(request.httpRequest.response);
        return;
      } else if (!allowedMethods.contains(method)) {
        // If method is not allowed, respond with 405 Method Not Allowed
        print('CORS Denied - Method not allowed: $method');
        response
            .setStatus(HttpStatus.methodNotAllowed); // 405 Method Not Allowed
        response.text('Method not allowed.');
        response.send(request.httpRequest.response);
        return;
      }

      // Set additional security headers (recommended for production)
      response.setHeader(
          'Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
      response.setHeader('X-Content-Type-Options', 'nosniff');
      response.setHeader('X-Frame-Options', 'DENY');

      // Proceed to the next middleware/handler if CORS checks pass
      await next();
    };
  }

  //rate limiter middleware
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
              'unkown'; //needs to be fixed or discussed : TODO
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
