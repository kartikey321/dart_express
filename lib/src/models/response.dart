import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';


class Response {
  int statusCode;
  dynamic body;
  Map<String, String> headers = {};
  bool isBinary = false;
  bool _isSent = false;

  bool get isSent => _isSent;

  Response({this.statusCode = 200, this.body, Map<String, String>? headers}) {
    if (headers != null) {
      this.headers.addAll(headers);
    }
  }

  void json(Map<String, dynamic> data) {
    body = jsonEncode(data);
    headers['Content-Type'] = ContentType.json.mimeType;
  }

  void text(String data) {
    body = data;
    headers['Content-Type'] = ContentType.text.mimeType;
  }

  void html(String html) {
    body = html;
    headers['Content-Type'] = ContentType.html.mimeType;
  }

  void xml(String xml) {
    body = xml;
    headers['Content-Type'] = 'application/xml';
  }

  void bytes(Uint8List bytes,
      {String contentType = 'application/octet-stream'}) {
    body = bytes;
    isBinary = true;
    headers['Content-Type'] = contentType;
    headers['Content-Length'] = bytes.length.toString();
  }

  Future<void> file(File file) async {
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
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'html':
        return ContentType.html.mimeType;
      case 'css':
        return 'text/css';
      case 'js':
        return 'application/javascript';
      case 'json':
        return ContentType.json.mimeType;
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'xml':
        return 'application/xml';
      case 'pdf':
        return 'application/pdf';

      default:
        return ContentType.binary.toString();
    }
  }

  void send(HttpResponse httpResponse) {
    if (isSent) return;
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
