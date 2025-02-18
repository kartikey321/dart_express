import 'dart:async';

import 'request.dart';
import 'response.dart';

typedef NextFunction = FutureOr<void> Function();
typedef MiddlewareFunction = Future<void> Function(
    Request request, Response response, NextFunction next);
typedef RequestHandler = FutureOr<void> Function(
    Request request, Response response);
    typedef MiddlewareHandler = FutureOr<void> Function(Request request, Response response, NextFunction next);


class Middleware {
  final String path;
  final MiddlewareFunction handler;

  Middleware(this.path, this.handler);
}


