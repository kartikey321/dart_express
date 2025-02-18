import 'package:meta/meta.dart';

import 'dart_express.dart';
import '../models/middleware.dart';

class ControllerOptions {
  late final DartExpress _app;
  late final String _prefix;
  ControllerOptions(this._app, this._prefix);
  void get(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    final fullPath = _joinPaths(path);
    _app.get(fullPath, handler, middleware: middleware);
  }

  void post(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    final fullPath = _joinPaths(path);
    _app.post(fullPath, handler, middleware: middleware);
  }

  void put(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    final fullPath = _joinPaths(path);
    _app.put(fullPath, handler, middleware: middleware);
  }

  void patch(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    final fullPath = _joinPaths(path);
    _app.patch(fullPath, handler, middleware: middleware);
  }

  void delete(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    final fullPath = _joinPaths(path);
    _app.delete(fullPath, handler, middleware: middleware);
  }

  String _joinPaths(String path) {
    if (_prefix.isEmpty) return path;
    if (path.startsWith('/')) path = path.substring(1);
    return '${_prefix.endsWith('/') ? _prefix : '$_prefix/'}$path';
  }
}

abstract class Controller {
  late final ControllerOptions _options;
  @mustCallSuper
  void initialize(DartExpress app, {String prefix = ''}) {
    _options = ControllerOptions(app, prefix);
    registerRoutes(_options);
  }

  void registerRoutes(ControllerOptions options);
}
