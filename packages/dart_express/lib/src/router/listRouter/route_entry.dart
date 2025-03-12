part of 'list_router.dart';

/// Handles path-to-regex conversion and parameter extraction
class _RoutePattern {
  final RegExp regex;
  final List<String> paramNames;

  _RoutePattern(this.regex, this.paramNames);

 /// Convert route path to regex pattern:
  /// - Replace :param with capture groups
  /// - Handle custom regex patterns (:param<pattern>)
  static _RoutePattern parse(String path) {
    final paramNames = <String>[];
    var pattern = path;

    // Replace named parameters with regex capture groups
    pattern = pattern.replaceAllMapped(
        RegExp(r':([a-zA-Z][a-zA-Z0-9_]*)\(([^)]+)\)'), (match) {
      paramNames.add(match.group(1)!);
      return '(${match.group(2)})';
    });

    pattern = pattern.replaceAllMapped(RegExp(r':([a-zA-Z][a-zA-Z0-9_]*)'), (match) {
      paramNames.add(match.group(1)!);
      return '([^/]+)';
    });

    pattern = pattern.replaceAll('/', '\\/');
    final regex = RegExp('^$pattern/?\$');
    return _RoutePattern(regex, paramNames);
  }
  /// Test if path matches the generated regex
  bool matches(String path) => regex.hasMatch(path);
  
  /// Extract parameter values from matched path
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

  _RouteEntry(this.method, String path, this.handler) : pattern = _RoutePattern.parse(path);

  bool matches(String method, String path) => this.method == method && pattern.matches(path);

  Map<String, String> extractParams(String path) => pattern.extractParams(path);
}