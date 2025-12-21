// radix_node.dart
part of 'radix_router.dart';

/// Represents a node in the radix tree routing structure
class RadixNode {
  /// The path segment this node represents
  final String segment;

  /// Child nodes keyed by their segment
  final Map<String, RadixNode> children = {};

  /// Named parameter for dynamic segments (null for static nodes)
  final String? paramName;

  /// Regex constraint for parameter validation (null for wildcards/static)
  final RegExp? regex;

  /// Registered handlers for different HTTP methods
  final Map<String, RequestHandler> handlers = {};
  RouterInterface? isolatedRouter;
  RadixNode._({
    required this.segment,
    this.paramName,
    this.regex,
  });

  /// Create root node
  factory RadixNode.root() => RadixNode._(segment: '');

  /// Create static route node
  factory RadixNode.static(String segment) => RadixNode._(segment: segment);

  /// Create dynamic route node
  factory RadixNode.dynamic(String segment, String paramName, RegExp? regex) =>
      RadixNode._(segment: segment, paramName: paramName, regex: regex);

  /// Whether this node represents a static path segment
  bool get isStatic => paramName == null;

  /// Whether this node represents a regex-constrained parameter
  bool get isRegex => isDynamic && regex != null;

  /// Whether this node represents a wildcard parameter
  bool get isWildcard => isDynamic && regex == null;

  /// Whether this node represents a dynamic parameter
  bool get isDynamic => paramName != null;
}
