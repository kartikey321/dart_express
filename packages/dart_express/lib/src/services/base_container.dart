import 'dart:io';

import 'package:dart_express/dart_express.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';

import '../router/router_interface.dart';
import 'error_handler.dart';

abstract class BaseContainer {
  final RouterInterface router;
  final List<MiddlewareHandler> _middleware = [];
  final GetIt container;
  ErrorHandler? _errorHandler;

  BaseContainer({RouterInterface? router, GetIt? container})
      : router = router ?? RadixRouter(),
        container = container ?? GetIt.instance;

  void use(MiddlewareHandler middleware) {
    _middleware.add(middleware);
  }

  void inject<T extends Object>(T instance) {
    container.registerSingleton<T>(instance);
  }

  void registerSingleton<T extends Object>(T instance) {
    container.registerSingleton<T>(instance);
  }

  void registerFactory<T extends Object>(T Function() factoryFunc) {
    container.registerFactory<T>(factoryFunc);
  }

  void registerLazySingleton<T extends Object>(T Function() factoryFunc) {
    container.registerLazySingleton<T>(factoryFunc);
  }

  void registerSingletonAsync<T extends Object>(
      Future<T> Function() asyncFactoryFunc) {
    container.registerSingletonAsync<T>(asyncFactoryFunc);
  }

  void registerFactoryAsync<T extends Object>(
      Future<T> Function() asyncFactoryFunc) {
    container.registerFactoryAsync<T>(asyncFactoryFunc);
  }

  void registerLazySingletonAsync<T extends Object>(
      Future<T> Function() asyncFactoryFunc) {
    container.registerLazySingletonAsync<T>(asyncFactoryFunc);
  }

  bool isRegistered<T extends Object>({Object? instance}) {
    return container.isRegistered<T>(instance: instance);
  }

  void unregister<T extends Object>() {
    container.unregister<T>();
  }

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

  @protected
  Future<void> handleRequest(HttpRequest httpRequest) async {
    final request = Request.from(httpRequest, container: container);
    final response = Response();

    try {
      final routeMatch = router.findRoute(request.method, request.uri.path);
      request.params = routeMatch?.pathParams ?? {};
      if (routeMatch != null) {
        await routeMatch.handler(request, response);
      } else {
        throw NotFoundError('Route not found: ${request.uri.path}');
      }
    } catch (error, stackTrace) {
      await handleError(error, request, response, stackTrace);
    }

    if (!response.isSent) {
      response.send(httpRequest.response);
    }
  }

  @protected
  Future<void> handleError(dynamic error, Request request, Response response,
      StackTrace stackTrace) async {
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
        response.json({'error': error.message, 'data': error.data});
      } else {
        response.setStatus(HttpStatus.internalServerError);
        response.json(
            {'error': 'Internal Server Error', 'message': error.toString()});
      }
    }
  }

  Future<void> onDispose() async {
    // Cleanup when controller is disposed
    container.reset();
  }
}
