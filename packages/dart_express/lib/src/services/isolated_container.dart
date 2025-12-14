import 'dart:io';

import 'package:dart_express/dart_express.dart';
import 'package:get_it/get_it.dart';

import '../router/router_interface.dart';

/// A container that can be mounted under a specific prefix with its own router,
/// middleware pipeline and dependency injection scope.
///
/// When mounted it reuses the parent [`Response`] instance so that cookies,
/// headers, and streaming behaviour are coordinated with the hosting
/// application while requests are rebuilt against the isolated dependency
/// scope.
class IsolatedContainer extends BaseContainer {
  IsolatedContainer({
    String prefix = '',
    super.router,
    GetIt? container,
  })  : prefix = _normalizePrefix(prefix),
        super(
          container: container ?? GetIt.asNewInstance(),
        );

  /// Public prefix exposed for introspection (always normalised to leading slash
  /// without trailing slash, except when empty).
  final String prefix;

  final Map<String, dynamic> cache = {};

  void get(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.GET, _normalizeLocalPath(path), handler,
        middleware: middleware);
  }

  void post(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.POST, _normalizeLocalPath(path), handler,
        middleware: middleware);
  }

  void put(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.PUT, _normalizeLocalPath(path), handler,
        middleware: middleware);
  }

  void patch(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.PATCH, _normalizeLocalPath(path), handler,
        middleware: middleware);
  }

  void delete(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.DELETE, _normalizeLocalPath(path), handler,
        middleware: middleware);
  }

  void options(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.OPTIONS, _normalizeLocalPath(path), handler,
        middleware: middleware);
  }

  /// Mounts this container into the provided [app], delegating only requests
  /// whose path matches the configured prefix via the parent router. This keeps
  /// path normalisation and parameter extraction consistent with the main
  /// routing strategy.
  void mount(DartExpress app) {
    final mountPrefix = prefix.isEmpty ? '/' : prefix;
    app.router.addIsolatedRouter(
      mountPrefix,
      _IsolatedRouterDelegate(this),
    );
  }

  /// Optional helper to run this container as a standalone service.
  Future<void> listen(int port, {InternetAddress? address}) async {
    address ??= InternetAddress.anyIPv4;
    final server = await HttpServer.bind(address, port);
    logger.i('Isolated container listening on port ${server.port}');
    await for (final httpRequest in server) {
      await handleRequest(httpRequest);
    }
  }

  @override
  String resolveRoutePath(Request request) {
    if (prefix.isEmpty) return request.uri.path;

    final path = request.uri.path;
    if (path == prefix || path == '$prefix/') {
      return '/';
    }

    final prefixedWithSlash = prefix.isEmpty ? '/' : '$prefix/';
    if (path.startsWith(prefixedWithSlash)) {
      final trimmed = path.substring(prefix.length);
      if (trimmed.isEmpty) return '/';
      return trimmed.startsWith('/') ? trimmed : '/$trimmed';
    }

    return request.uri.path;
  }

  @override
  Future<void> onDispose() {
    cache.clear();
    return super.onDispose();
  }

  /// Public hook to process a scoped request inside this container.
  Future<void> handleScoped(Request request, Response response) {
    return processRequest(request, response);
  }

  static String _normalizeLocalPath(String path) {
    if (path.isEmpty) return '/';
    return path.startsWith('/') ? path : '/$path';
  }

  static String _normalizePrefix(String prefix) {
    var value = prefix.trim();
    if (value.isEmpty || value == '/') {
      return '';
    }
    if (!value.startsWith('/')) {
      value = '/$value';
    }
    if (value.endsWith('/') && value.length > 1) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}

class _IsolatedRouterDelegate implements RouterInterface {
  _IsolatedRouterDelegate(this.container);

  final IsolatedContainer container;

  @override
  void addRoute(String method, String path, RequestHandler handler) {
    container.router.addRoute(method, path, handler);
  }

  @override
  void addIsolatedRouter(String prefix, RouterInterface router) {
    container.router.addIsolatedRouter(prefix, router);
  }

  @override
  RouteMatch? findRoute(String method, String path) {
    final delegateMatch = container.router.findRoute(method, path);
    if (delegateMatch == null) {
      return null;
    }

    return RouteMatch(
      (parentRequest, parentResponse) async {
        // Reuse parent session and store for isolated containers.
        // This ensures session data is shared and persisted correctly.
        // We don't need to pass sessionStore again because we're sharing
        // the parent Session object which already has its store reference.
        final scopedRequest = Request(
          parentRequest.httpRequest,
          parentRequest.session, // Share session (already has store)
          parentRequest.requestId,
          container.container,
          sessionSigner: parentRequest.sessionSigner,
        );

        await container.handleScoped(scopedRequest, parentResponse);
      },
      pathParams: delegateMatch.pathParams,
    );
  }
}
