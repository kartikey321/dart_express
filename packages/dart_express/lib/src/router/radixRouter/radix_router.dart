// radix_router.dart
import 'package:dart_express/dart_express.dart';
import 'package:dart_express/src/router/router_interface.dart';
import 'package:dart_express/src/services/error_handler.dart';

part 'radix_node.dart';

/// A high-performance router using a radix tree structure for efficient route matching.
/// Supports:
/// - Static routes (/users/profile)
/// - Parameter routes with regex constraints (/users/:id(\d+))
/// - Wildcard parameters (/users/:username)
/// 
/// Route matching priority:
/// 1. Static routes
/// 2. Regex-constrained parameters
/// 3. Wildcard parameters
class RadixRouter implements RouterInterface {
  final RadixNode _root = RadixNode.root();
  final Set<String> _registeredPaths = {};

  @override
  void addRoute(String method, String path, RequestHandler handler) {
    final normalizedPath = _normalizePath(path);
    final routeKey = '$method:$normalizedPath';

    if (_registeredPaths.contains(routeKey)) {
      throw RouteConflictError('Route $method $path already registered');
    }
    _registeredPaths.add(routeKey);

    final segments = _splitPath(normalizedPath);
    var currentNode = _root;

    for (final segment in segments) {
      currentNode = _getOrCreateNode(currentNode, segment);
    }

    if (currentNode.handlers.containsKey(method)) {
      throw RouteConflictError('Handler already exists for $method $path');
    }
    currentNode.handlers[method] = handler;
  }

  @override
  RouteMatch? findRoute(String method, String path) {
    final normalizedPath = _normalizePath(path);
    final segments = _splitPath(normalizedPath);
    final params = <String, String>{};
    
    final handler = _matchSegments(_root, segments, 0, method, params);
    return handler != null ? RouteMatch(handler, pathParams: params) : null;
  }

  // Internal implementation details
  RadixNode _getOrCreateNode(RadixNode parent, String segment) {
    if (parent.children.containsKey(segment)) {
      return parent.children[segment]!;
    }

    final newNode = _createNode(segment);
    parent.children[segment] = newNode;
    return newNode;
  }

  RadixNode _createNode(String segment) {
    if (segment.startsWith(':')) {
      final match = RegExp(r':([a-zA-Z_]\w*)(?:\(([^)]+)\))?').firstMatch(segment);
      if (match == null) throw FormatException('Invalid path segment: $segment');

      final paramName = match.group(1)!;
      final regex = match.group(2) != null ? RegExp('^${match.group(2)}\$') : null;
      
      return RadixNode.dynamic(segment, paramName, regex);
    }
    return RadixNode.static(segment);
  }

  RequestHandler? _matchSegments(
    RadixNode node,
    List<String> segments,
    int depth,
    String method,
    Map<String, String> params,
  ) {
    if (depth == segments.length) {
      return node.handlers[method];
    }

    final segment = segments[depth];
    final processed = <RadixNode>[];

    // Process in priority order: static -> regex -> wildcard
    for (final child in node.children.values) {
      if (child.isStatic && child.segment == segment) {
        final handler = _matchSegments(child, segments, depth + 1, method, params);
        if (handler != null) return handler;
        processed.add(child);
      }
    }

    for (final child in node.children.values.where((c) => c.isRegex && !processed.contains(c))) {
      if (child.regex!.hasMatch(segment)) {
        final paramBackup = _handleParam(child, params, segment);
        final handler = _matchSegments(child, segments, depth + 1, method, params);
        if (handler != null) return handler;
        _restoreParam(child, params, paramBackup);
        processed.add(child);
      }
    }

    for (final child in node.children.values.where((c) => c.isWildcard && !processed.contains(c))) {
      final paramBackup = _handleParam(child, params, segment);
      final handler = _matchSegments(child, segments, depth + 1, method, params);
      if (handler != null) return handler;
      _restoreParam(child, params, paramBackup);
    }

    return null;
  }

  String _normalizePath(String path) => path
      .replaceAll(RegExp(r'/+'), '/')  // Collapse multiple slashes
      .replaceAll(RegExp(r'^/|/$'), ''); // Trim leading/trailing slashes

  List<String> _splitPath(String path) => path.split('/');

  String? _handleParam(RadixNode node, Map<String, String> params, String value) {
    if (!node.isDynamic) return null;
    final backup = params[node.paramName!];
    params[node.paramName!] = value;
    return backup;
  }

  void _restoreParam(RadixNode node, Map<String, String> params, String? backup) {
    if (!node.isDynamic) return;
    if (backup != null) {
      params[node.paramName!] = backup;
    } else {
      params.remove(node.paramName!);
    }
  }
}