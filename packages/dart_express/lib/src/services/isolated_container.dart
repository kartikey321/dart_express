import 'dart:io';

import 'package:dart_express/dart_express.dart';

class IsolatedContainer extends BaseContainer {
  final String prefix;
  final Map<String, dynamic> cache = {};

  IsolatedContainer({this.prefix = '', super.router});

  void get(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.GET, _prefixPath(path), handler,
        middleware: middleware);
  }

  void post(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.POST, _prefixPath(path), handler,
        middleware: middleware);
  }

  void put(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.PUT, _prefixPath(path), handler,
        middleware: middleware);
  }

  void patch(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.PATCH, _prefixPath(path), handler,
        middleware: middleware);
  }

  void delete(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.DELETE, _prefixPath(path), handler,
        middleware: middleware);
  }

  void options(String path, RequestHandler handler,
      {List<MiddlewareHandler>? middleware}) {
    addRoute(RequestTypes.OPTIONS, _prefixPath(path), handler,
        middleware: middleware);
  }

  String _prefixPath(String path) {
    if (prefix.isEmpty) return path;
    return prefix + (path.startsWith('/') ? path : '/$path');
  }

  void mount(DartExpress app) {
    app.use((req, res, next) async {
      if (req.uri.path.startsWith(prefix)) {
        await handleRequest(req.httpRequest);
      } else {
        await next();
      }
    });
  }

  Future<void> listen(int port) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('Isolated container listening on port ${server.port}');
    await for (HttpRequest httpRequest in server) {
      await handleRequest(httpRequest);
    }
  }

  @override
  Future<void> onDispose() {
    // TODO: implement onDispose
    // Perform any cleanup or resource release here
    cache.clear();

    return super.onDispose();
  }
}
