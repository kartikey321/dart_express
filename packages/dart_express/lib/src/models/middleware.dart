import 'dart:async';

import 'request.dart';
import 'response.dart';

/// Continuation invoked by middleware to advance the pipeline.
typedef NextFunction = FutureOr<void> Function();

/// Signature for middleware functions that can perform asynchronous work.
typedef MiddlewareFunction = Future<void> Function(
    Request request, Response response, NextFunction next);

/// Signature for route handlers.
typedef RequestHandler = FutureOr<void> Function(
    Request request, Response response);

/// Alias used across the framework for middleware registration.
typedef MiddlewareHandler = FutureOr<void> Function(
    Request request, Response response, NextFunction next);

/// Wrapper describing a middleware bound to a specific [path].
class Middleware {
  final String path;
  final MiddlewareFunction handler;

  Middleware(this.path, this.handler);
}
