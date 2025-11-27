import 'dart:io';

import 'package:dart_express/dart_express.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

import '../router/router_interface.dart';
import 'error_handler.dart';

/// Core runtime wiring shared by [DartExpress] and other container variants.
/// Provides middleware composition, dependency registration helpers, and
/// request lifecycle utilities.
abstract class BaseContainer {
  final RouterInterface router;
  final List<MiddlewareHandler> _middleware = [];
  final GetIt container;
  ErrorHandler? _errorHandler;

  /// Creates a container with optional overrides for router and dependency
  /// scope.
  BaseContainer({RouterInterface? router, GetIt? container})
      : router = router ?? RadixRouter(),
        container = container ?? GetIt.instance;

  /// Adds a global [middleware] to the container.
  void use(MiddlewareHandler middleware) {
    _middleware.add(middleware);
  }

  /// Registers a pre-built [instance] that will be served for type [T].
  void inject<T extends Object>(T instance) {
    container.registerSingleton<T>(instance);
  }

  /// Registers an eagerly created singleton for [T].
  void registerSingleton<T extends Object>(T instance) {
    container.registerSingleton<T>(instance);
  }

  /// Registers a factory invoked on each access to [T].
  void registerFactory<T extends Object>(T Function() factoryFunc) {
    container.registerFactory<T>(factoryFunc);
  }

  /// Registers a lazily created singleton for [T].
  void registerLazySingleton<T extends Object>(T Function() factoryFunc) {
    container.registerLazySingleton<T>(factoryFunc);
  }

  /// Registers an asynchronously produced singleton.
  void registerSingletonAsync<T extends Object>(
      Future<T> Function() asyncFactoryFunc) {
    container.registerSingletonAsync<T>(asyncFactoryFunc);
  }

  /// Registers an asynchronously produced factory provider.
  void registerFactoryAsync<T extends Object>(
      Future<T> Function() asyncFactoryFunc) {
    container.registerFactoryAsync<T>(asyncFactoryFunc);
  }

  /// Registers an asynchronously produced lazy singleton.
  void registerLazySingletonAsync<T extends Object>(
      Future<T> Function() asyncFactoryFunc) {
    container.registerLazySingletonAsync<T>(asyncFactoryFunc);
  }

  /// Checks whether [T] is already registered.
  bool isRegistered<T extends Object>({Object? instance}) {
    return container.isRegistered<T>(instance: instance);
  }

  /// Unregisters the existing binding for [T].
  void unregister<T extends Object>() {
    container.unregister<T>();
  }

  /// Installs a global error handler.
  void setErrorHandler(ErrorHandler handler) {
    _errorHandler = handler;
  }

  @protected
  RequestHandler wrapWithMiddleware(
      RequestHandler handler, List<MiddlewareHandler> routeMiddleware) {
    return (Request request, Response response) async {
      int globalIndex = 0;
      int routeIndex = 0;

      Future<void> runNextMiddleware() async {
        if (globalIndex < _middleware.length) {
          await _middleware[globalIndex++](
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

  @protected
  void addRoute(String method, String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    final wrappedHandler = wrapWithMiddleware(handler, middleware ?? []);
    router.addRoute(method, path, wrappedHandler);
  }

  /// Orchestrates the full request lifecycle: building framework abstractions,
  /// resolving routes, executing middleware/handlers and finally flushing the
  /// response (including error handling and session propagation).
  @protected
  Future<void> handleRequest(HttpRequest httpRequest) async {
    final request = Request.from(httpRequest, container: container);
    final response = Response();
    await processRequest(request, response);
  }

  /// Executes middleware + handler pipeline for a prepared [request] and
  /// [response]. If a route does not complete the response, it is sent here.
  @protected
  Future<void> processRequest(Request request, Response response) async {
    if (request.isNewSession &&
        !response.hasCookie(Request.sessionCookieName)) {
      response.cookie(
        Request.sessionCookieName,
        request.session.id,
        secure: false,
        httpOnly: true,
      );
    }

    try {
      final resolvedPath = resolveRoutePath(request);
      final routeMatch = router.findRoute(request.method, resolvedPath);
      request.params = routeMatch?.pathParams ?? {};
      if (routeMatch != null) {
        await routeMatch.handler(request, response);
      } else {
        throw NotFoundError('Route not found: $resolvedPath');
      }
    } catch (error, stackTrace) {
      await handleError(error, request, response, stackTrace);
    }

    if (!response.isSent) {
      response.send(request.httpRequest.response);
    }
  }

  /// Resolves the path used for route lookup. Subclasses can override to provide
  /// custom behaviour (e.g., stripping a mount prefix).
  @protected
  String resolveRoutePath(Request request) => request.uri.path;

  /// Default error handling entry point. Subclasses may override to plug in
  /// different behaviour.
  @protected
  Future<void> handleError(dynamic error, Request request, Response response,
      StackTrace stackTrace) async {
    if (_errorHandler != null) {
      try {
        await _errorHandler!(error, request, response);
        // Ensure error handler actually sent a response
        if (!response.isSent) {
          print('Warning: Error handler did not send response, using fallback');
          _sendDefaultError(error, response, stackTrace);
        }
      } catch (e, st) {
        print('Error in error handler: $e\n$st');
        // Fall through to default error handling
        if (!response.isSent) {
          _sendDefaultError(error, response, stackTrace);
        }
      }
    } else {
      _sendDefaultError(error, response, stackTrace);
    }
  }

  void _sendDefaultError(
      dynamic error, Response response, StackTrace stackTrace) {
    if (response.isSent) return;

    print('Unhandled error: $error\nStackTrace: $stackTrace');
    if (error is HttpError) {
      response.setStatus(error.statusCode);
      response.json({'error': error.message, 'data': error.data});
    } else {
      response.setStatus(HttpStatus.internalServerError);
      response.json(
          {'error': 'Internal Server Error', 'message': error.toString()});
    }
  }

  /// Disposes the dependency container and any subclass resources.
  Future<void> onDispose() async {
    container.reset();
  }
}
