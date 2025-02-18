import 'middleware.dart';

class RoutePattern {
  final RegExp regex;
  final List<String> paramNames;

  RoutePattern(this.regex, this.paramNames);

  static RoutePattern parse(String path) {
    final paramNames = <String>[];
    var pattern = path;

    // Replace named parameters with regex capture groups
    pattern = pattern.replaceAllMapped(
        RegExp(r':([a-zA-Z][a-zA-Z0-9_]*)\(([^)]+)\)'), (match) {
      paramNames.add(match.group(1)!);
      return '(${match.group(2)})';
    });

    // Replace simple named parameters with word capture groups
    pattern =
        pattern.replaceAllMapped(RegExp(r':([a-zA-Z][a-zA-Z0-9_]*)'), (match) {
      paramNames.add(match.group(1)!);
      return '([^/]+)';
    });

    // Escape forward slashes and create regex
    pattern = pattern.replaceAll('/', '\\/');
    final regex = RegExp('^${pattern}/?\$');

    return RoutePattern(regex, paramNames);
  }
}

class RouteEntry {
  final String method;
  final RoutePattern pattern;
  final RequestHandler handler;

  RouteEntry(this.method, String path, this.handler)
      : pattern = RoutePattern.parse(path);

  bool matches(String path) {
    return pattern.regex.hasMatch(path);
  }

  Map<String, String> extractParams(String path) {
    final match = pattern.regex.firstMatch(path);

    if (match == null) return {};

    final params = <String, String>{};
    for (var i = 0; i < pattern.paramNames.length; i++) {
      params[pattern.paramNames[i]] = match.group(i + 1)!;
    }
    return params;
  }
}
