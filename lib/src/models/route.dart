import 'middleware.dart';

class RouteEntry {
  final String method;
  final List<String> segments;
  final RequestHandler handler;

  RouteEntry(this.method, this.segments, this.handler);

  bool matches(List<String> pathSegments) {
    if (segments.length != pathSegments.length) return false;
    for (var i = 0; i < segments.length; i++) {
      if (!segments[i].startsWith(':') && segments[i] != pathSegments[i]) {
        return false;
      }
    }
    return true;
  }

  Map<String, String> extractParams(List<String> pathSegments) {
    var params = <String, String>{};
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].startsWith(':')) {
        params[segments[i].substring(1)] = pathSegments[i];
      }
    }
    return params;
  }
}
