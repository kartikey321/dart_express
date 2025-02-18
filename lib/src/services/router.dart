import '../models/middleware.dart';
import '../models/route.dart';

// Router Class
class Router {
  final List<RouteEntry> _routes = [];

  void addRoute(String method, String path, RequestHandler handler) {
    final segments = _normalizePath(path);
    _routes.add(RouteEntry(method, segments, handler));
  }

  RequestHandler? findHandler(String method, String path) {
    final pathSegments = _normalizePath(path);
    for (var route in _routes) {
      if (route.method == method && route.matches(pathSegments)) {
        return (request, response) {
          request.params = route.extractParams(pathSegments);
          return route.handler(request, response);
        };
      }
    }
    return null;
  }

  List<String> _normalizePath(String path) {
    return path.split('/').where((segment) => segment.isNotEmpty).toList();
  }
}
