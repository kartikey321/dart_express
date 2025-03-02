import 'dart:async';
import 'dart:convert';
import 'dart:io' ;
import 'dart:typed_data';
import 'package:mime/mime.dart';


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

    _cookies.add(cookie);
  }

  void clearCookie(String name, {String? path, String? domain}) {
    final cookie = Cookie(name, '')
      ..maxAge = 0
      ..expires = DateTime.utc(1970)
      ..path = path
      ..domain = domain;
    _cookies.add(cookie);
  }

  void _setCookieHeaders() {
    if (_cookies.isNotEmpty) {
      headers[HttpHeaders.setCookieHeader] = _cookies.map((c) => c.toString()).join(', ');
    }
  }

  void json(Map<String, dynamic> data, {int? statusCode}) {
    body = jsonEncode(data);
    headers['Content-Type'] = ContentType.json.mimeType;
    if (statusCode != null) {
      setStatus(statusCode);
    }
  }

  void text(String data, {int? statusCode}) {
    body = data;
    headers['Content-Type'] = ContentType.text.mimeType;
    if (statusCode != null) {
      setStatus(statusCode);
    }
  }

  void html(String html, {int? statusCode}) {
    body = html;
    headers['Content-Type'] = ContentType.html.mimeType;
  }

  void xml(String xml, {int? statusCode}) {
    body = xml;
    headers['Content-Type'] = 'application/xml';
    if (statusCode != null) {
      setStatus(statusCode);
    }
  }

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

  void redirect(String url, {int status = HttpStatus.movedPermanently}) {
    statusCode = status;
    headers['Location'] = url;
  }

static String _getContentType(String filePath) {
  return lookupMimeType(filePath) ?? 'application/octet-stream';
}

  void send(HttpResponse httpResponse) {
    if (isSent) return;
    _setCookieHeaders();
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
}
