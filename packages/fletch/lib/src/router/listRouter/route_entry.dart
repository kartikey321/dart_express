// route_entry.dart
part of 'list_router.dart';

class _RoutePattern {
  final RegExp regex;
  final List<String> paramNames;

  _RoutePattern(this.regex, this.paramNames);

  static _RoutePattern parse(String path) {
    final paramNames = <String>[];
    var pattern = path;

    pattern = pattern.replaceAllMapped(
        RegExp(r':([a-zA-Z][a-zA-Z0-9_]*)\(([^)]+)\)'), (match) {
      paramNames.add(match.group(1)!);
      return '(${match.group(2)})';
    });

    pattern =
        pattern.replaceAllMapped(RegExp(r':([a-zA-Z][a-zA-Z0-9_]*)'), (match) {
      paramNames.add(match.group(1)!);
      return '([^/]+)';
    });

    pattern = pattern.replaceAll('/', '\\/');
    final regex = RegExp('^$pattern/?\$');
    return _RoutePattern(regex, paramNames);
  }

  bool matches(String path) => regex.hasMatch(path);

  Map<String, String> extractParams(String path) {
    final match = regex.firstMatch(path);
    if (match == null) return {};
    final params = <String, String>{};
    for (var i = 0; i < paramNames.length; i++) {
      params[paramNames[i]] = match.group(i + 1)!;
    }
    return params;
  }
}

class _RouteEntry {
  final String method;
  final _RoutePattern pattern;
  final RequestHandler handler;
  final RouterInterface? isolatedRouter;
  final String? prefix;

  _RouteEntry.route(this.method, String path, this.handler)
      : pattern = _RoutePattern.parse(path),
        isolatedRouter = null,
        prefix = null;

  _RouteEntry.isolated(this.prefix, this.isolatedRouter)
      : method = '',
        pattern = _RoutePattern.parse(prefix!),
        handler = ((req, res) => Future.value());

  bool matches(String method, String path) {
    if (isolatedRouter != null) {
      return path.startsWith(prefix!);
    }
    return this.method == method && pattern.matches(path);
  }

  Map<String, String> extractParams(String path) => pattern.extractParams(path);
}
