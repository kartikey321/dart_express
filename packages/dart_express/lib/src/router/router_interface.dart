import 'package:dart_express/dart_express.dart';

/// Defines the common interface for all router implementations
abstract class RouterInterface {
  /// Add a route to the router
  /// [method] - HTTP method (GET, POST, etc.)
  /// [path] - URL path pattern with optional parameters
  /// [handler] - Request handler function
  void addRoute(String method, String path, RequestHandler handler);

  /// Find a matching route for incoming request
  /// Returns [RouteMatch] with handler and parameters if found
  RouteMatch? findRoute(String method, String path);
}

/// Container for matched route results
class RouteMatch {
  /// The request handler to execute
  final RequestHandler handler;
  
  /// Path parameters extracted from the URL
  final Map<String, String> pathParams;

  RouteMatch(this.handler, {Map<String, String>? pathParams})
      : pathParams = pathParams ?? {};
}