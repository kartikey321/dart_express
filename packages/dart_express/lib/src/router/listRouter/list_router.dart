import 'package:dart_express/dart_express.dart';
import 'package:dart_express/src/router/router_interface.dart';
part 'route_entry.dart';
/// Router using linear search with regex pattern matching
/// Best for small applications with simple routing needs
class ListRouter implements RouterInterface {
  final List<_RouteEntry> _routes = [];

  /// Add route to internal list
  @override
  void addRoute(String method, String path, RequestHandler handler) {
    _routes.add(_RouteEntry(method, path, handler));
  }

  /// Find route by checking each entry sequentially
  @override
  RouteMatch? findRoute(String method, String path) {
    for (var route in _routes) {
      if (route.matches(method, path)) {
        return RouteMatch(
          route.handler,
          pathParams: route.extractParams(path),
        );
      }
    }
    return null;
  }
}