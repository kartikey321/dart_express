import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dart_express/dart_express.dart';
import 'package:mime/mime.dart';


class Request {
  final HttpRequest httpRequest;
  Map<String, String> params = {};
  late final Map<String, String> query;
  final Session session;
  final DIContainer container;
  Map<String, dynamic>? _body;
  Map<String, dynamic>? _formData;
  Map<String, List<MultipartFile>>? _files;
   List<Cookie> cookies = [];

  Request(this.httpRequest, this.session, this.container) {
    query = httpRequest.uri.queryParameters;
  }

  String get method => httpRequest.method;
  Uri get uri => httpRequest.uri;
  HttpHeaders get headers => httpRequest.headers;

  Future<Map<String, dynamic>> get body async {
    if (_body == null) {
      final contentType = headers.contentType?.mimeType;
      if (contentType == 'application/json') {
        _body = json.decode(await utf8.decoder.bind(httpRequest).join());
      } else if (contentType == 'application/x-www-form-urlencoded') {
        _body = uri.queryParameters;
      }
    }
    return _body ?? {};
  }

  Future<Map<String, dynamic>> get formData async {
    if (_formData == null) {
      final contentType = headers.contentType?.mimeType;
      if (contentType == 'multipart/form-data') {
        final boundary = headers.contentType!.parameters['boundary']!;
        final transformer = MimeMultipartTransformer(boundary);
        final parts = await transformer.bind(httpRequest).toList();

        _formData = {};
        _files = {};

        for (var part in parts) {
          final contentDisposition = part.headers['content-disposition'];
          final name = RegExp(r'name="([^"]*)"')
              .firstMatch(contentDisposition!)!
              .group(1)!;

          if (contentDisposition.contains('filename')) {
            final filename = RegExp(r'filename="([^"]*)"')
                .firstMatch(contentDisposition)!
                .group(1)!;
            final contentBytes =
                await consolidateBytes(part); // Use helper to fully read stream
            final file =
                MultipartFile.fromBytes(name, contentBytes, filename: filename);
            _files![name] = (_files![name] ?? [])..add(file);
          } else {
            final value = await utf8.decoder.bind(part).join();
            _formData![name] = value;
          }
        }
      }
    }
    // return (_files != null && _files!.isNotEmpty) ? _files! : (_formData ?? {});
    Map<String, dynamic> returnMap = {};
    if (_files != null) {
      returnMap.addEntries(_files!.entries);
    }
    if (_formData != null) {
      returnMap.addEntries(_formData!.entries);
    }
    return returnMap;
  }

  factory Request.from(
    HttpRequest httpRequest, {
    required DIContainer container,
  }) {
    final sessionId = httpRequest.cookies
        .firstWhere(
          (cookie) => cookie.name == 'sessionId',
          orElse: () => Cookie('sessionId', _generateSessionId()),
        )
        .value;
    final session = Session(sessionId);

    return Request(httpRequest, session, container);
  }

  static String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }

  Future<Map<String, List<MultipartFile>>> get files async {
    await formData; // Ensure formData has been processed
    return _files ?? {};
  }

  // Helper method to read stream fully into a list of bytes to prevent multiple listens
  static Future<List<int>> consolidateBytes(Stream<List<int>> stream) async {
    final buffer = BytesBuilder();
    await for (final chunk in stream) {
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  }
}

class Session {
  final String id;
  final Map<String, dynamic> data = {};

  Session(this.id);
}
