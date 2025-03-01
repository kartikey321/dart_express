import '../models/middleware.dart';
import '../models/route.dart';

// Router Class
class Router {
  final List<RouteEntry> _routes = [];

  void addRoute(String method, String path, RequestHandler handler) {
    _routes.add(RouteEntry(method, path, handler));
  }

  RequestHandler? findHandler(String method, String path) {
    for (var route in _routes) {
      if (route.method == method && route.matches(path)) {
        return (request, response) {
          request.params = route.extractParams(path);
          return route.handler(request, response);
        };
      }
    }
    return null;
  }
}
