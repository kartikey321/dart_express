import 'dart:async';
import 'dart:io';

import 'package:fletch/fletch.dart';
import 'package:http/http.dart' as http;

/// Lightweight harness that spins up a [Fletch] instance on a random
/// ephemeral port and exposes helpers for common request patterns used in
/// tests.
class TestServerHarness {
  TestServerHarness({Fletch? app, InternetAddress? address})
      : app = app ?? Fletch(),
        address = address ?? InternetAddress.loopbackIPv4;

  final Fletch app;
  final InternetAddress address;
  HttpServer? _server;
  int? _boundPort;

  int get port => _boundPort ?? _server?.port ?? 0;

  /// Starts the underlying [HttpServer] if not already running.
  Future<void> start() async {
    if (_server != null) return;
    _server = await app.listen(0, address: address);
    _boundPort = _server?.port;
  }

  /// Resolved absolute [Uri] for the given [path].
  Uri uri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('http://${address.address}:$port$normalized');
  }

  Future<http.Response> get(String path,
      {Map<String, String>? headers}) async {
    await start();
    return http.get(uri(path), headers: headers);
  }

  Future<http.Response> post(String path,
      {Object? body, Map<String, String>? headers}) async {
    await start();
    return http.post(uri(path), body: body, headers: headers);
  }

  Future<http.Response> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    await start();
    final request = http.Request(method, uri(path));
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List<int>) {
        request.bodyBytes = body;
      } else if (body is Map<String, String>) {
        request.bodyFields = body;
      } else {
        throw ArgumentError('Unsupported body type: ${body.runtimeType}');
      }
    }
    if (headers != null) {
      request.headers.addAll(headers);
    }
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  Future<http.StreamedResponse> sendStream(
    String method,
    String path, {
    Stream<List<int>>? body,
    Map<String, String>? headers,
  }) async {
    await start();
    final request = http.StreamedRequest(method, uri(path));
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      await for (final chunk in body) {
        request.sink.add(chunk);
      }
    }
    await request.sink.close();
    return request.send();
  }

  Future<http.StreamedResponse> sendMultipart(http.MultipartRequest request) {
    return start().then((_) => request.send());
  }

  /// Closes the server and underlying container.
  Future<void> dispose() async {
    final server = _server;
    if (server != null) {
      try {
        await app.close();
      } catch (_) {}
      try {
        await server.close(force: true);
      } catch (_) {}
      await app.waitUntilClosed(server);
      _server = null;
    } else {
      await app.onDispose();
    }
  }
}
