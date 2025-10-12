import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';

/// Represents an outgoing HTTP response with helpers for composing common
/// payload types and managing headers/cookies before the underlying
/// [HttpResponse] is closed.
class Response {
  int statusCode;
  dynamic body;
  Map<String, String> headers = {};
  bool isBinary = false;
  bool _isSent = false;
  final List<Cookie> _cookies = [];
  bool get isSent => _isSent;

  Response({this.statusCode = 200, this.body, Map<String, String>? headers}) {
    if (headers != null) {
      this.headers.addAll(headers);
    }
  }

  /// Adds or replaces a cookie on the response. Existing cookies with the same
  /// name and path are overwritten to avoid duplicate `Set-Cookie` headers.
  void cookie(
    String name,
    String value, {
    DateTime? expires,
    int? maxAge,
    String? domain,
    String? path,
    bool secure = true,
    bool httpOnly = true,
    SameSite? sameSite = SameSite.lax,
  }) {
    final cookie = Cookie(name, value)
      ..expires = expires
      ..maxAge = maxAge
      ..domain = domain
      ..path = path ?? '/'
      ..secure = secure
      ..httpOnly = httpOnly;

    if (sameSite != null) {
      cookie.sameSite = sameSite;
    }

    _replaceCookie(cookie);
  }

  /// Removes a cookie by setting an expired value for the provided name.
  void clearCookie(String name, {String? path, String? domain}) {
    final cookie = Cookie(name, '')
      ..maxAge = 0
      ..expires = DateTime.utc(1970)
      ..path = path
      ..domain = domain;
    _replaceCookie(cookie);
  }

  /// Returns `true` when a cookie with the given [name] (and optional [path])
  /// is queued for the response.
  bool hasCookie(String name, {String? path}) {
    return _cookies.any((cookie) {
      if (cookie.name != name) return false;
      if (path == null) return true;
      return (cookie.path ?? '/') == path;
    });
  }

  /// Serialises a JSON payload and updates the response metadata accordingly.
  void json(Map<String, dynamic> data, {int? statusCode}) {
    body = jsonEncode(data);
    headers['Content-Type'] = ContentType.json.mimeType;
    if (statusCode != null) {
      setStatus(statusCode);
    }
  }

  /// Writes a plain text payload to the response.
  void text(String data, {int? statusCode}) {
    body = data;
    headers['Content-Type'] = ContentType.text.mimeType;
    if (statusCode != null) {
      setStatus(statusCode);
    }
  }

  /// Writes an HTML payload to the response.
  void html(String html, {int? statusCode}) {
    body = html;
    headers['Content-Type'] = ContentType.html.mimeType;
    if (statusCode != null) {
      setStatus(statusCode);
    }
  }

  /// Writes an XML payload to the response.
  void xml(String xml, {int? statusCode}) {
    body = xml;
    headers['Content-Type'] = 'application/xml';
    if (statusCode != null) {
      setStatus(statusCode);
    }
  }

  /// Streams raw bytes to the client using the supplied content-type.
  void bytes(Uint8List bytes,
      {String contentType = 'application/octet-stream', int? statusCode}) {
    body = bytes;
    isBinary = true;
    headers['Content-Type'] = contentType;
    headers['Content-Length'] = bytes.length.toString();
    if (statusCode != null) {
      setStatus(statusCode);
    }
  }

  /// Reads a file from disk and emits it as the response body. Responds with
  /// a 404 when the file does not exist.
  Future<void> file(
    File file,
  ) async {
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      this.bytes(bytes, contentType: _getContentType(file.path));
    } else {
      statusCode = HttpStatus.notFound;
      text('File not found');
    }
  }

  /// Issues an HTTP redirect by setting the appropriate status code and
  /// `Location` header.
  void redirect(String url, {int status = HttpStatus.movedPermanently}) {
    statusCode = status;
    headers['Location'] = url;
  }

  static String _getContentType(String filePath) {
    return lookupMimeType(filePath) ?? 'application/octet-stream';
  }

  /// Flushes the accumulated headers/cookies into the provided [HttpResponse]
  /// and closes the sink. Subsequent invocations are ignored.
  void send(HttpResponse httpResponse) {
    if (isSent) return;
    _writeCookies(httpResponse);
    _isSent = true;

    httpResponse.statusCode = statusCode;

    headers.forEach((name, value) {
      httpResponse.headers.set(name, value);
    });

    if (isBinary) {
      httpResponse.add(body as Uint8List);
    } else if (body != null) {
      httpResponse.write(body);
    }

    httpResponse.close();
  }

  void setHeader(String name, String value) {
    headers[name] = value;
  }

  void setStatus(int code) {
    statusCode = code;
  }

  void _writeCookies(HttpResponse httpResponse) {
    if (_cookies.isEmpty) {
      return;
    }

    for (final cookie in _cookies) {
      httpResponse.cookies.add(cookie);
    }
  }

  void _replaceCookie(Cookie cookie) {
    _cookies.removeWhere((existing) {
      final sameName = existing.name == cookie.name;
      final existingPath = existing.path ?? '/';
      final newPath = cookie.path ?? '/';
      return sameName && existingPath == newPath;
    });
    _cookies.add(cookie);
  }
}
