import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_express/dart_express.dart';
import 'package:get_it/get_it.dart';
import 'package:mime/mime.dart';

/// Represents an incoming HTTP request flowing through the framework.
///
/// Exposes helpers for accessing parsed payloads, form data, uploaded files
/// and dependency-injected services while ensuring the underlying stream is
/// consumed exactly once.
class Request {
  final HttpRequest httpRequest;
  Map<String, String> params = {};
  late final Map<String, String> query;
  final Session session;
  final GetIt container;
  Object? _parsedBody;
  Future<Uint8List>? _bodyBytesFuture;
  _FormDataPayload? _multipartPayload;
  Map<String, dynamic>? _formDataCache;
  final bool _isSessionNew;
  List<Cookie> cookies = [];

  Request(this.httpRequest, this.session, this.container,
      {bool isSessionNew = false})
      : _isSessionNew = isSessionNew {
    query = httpRequest.uri.queryParameters;
  }

  String get method => httpRequest.method;
  Uri get uri => httpRequest.uri;
  HttpHeaders get headers => httpRequest.headers;

  /// Returns the parsed request body.
  ///
  /// * JSON payloads are decoded via `jsonDecode`
  /// * `application/x-www-form-urlencoded` payloads return a map of fields
  /// * Text payloads resolve to a `String`
  /// * All other content types yield the raw `Uint8List`
  Future<Object?> get body async {
    if (_parsedBody != null) {
      return _parsedBody;
    }

    final contentType = headers.contentType?.mimeType ?? '';
    final bodyBytes = await _ensureBodyBytes();

    if (bodyBytes.isEmpty) {
      _parsedBody = null;
      return _parsedBody;
    }

    if (contentType == ContentType.json.mimeType ||
        contentType.endsWith('+json')) {
      _parsedBody = jsonDecode(utf8.decode(bodyBytes));
      return _parsedBody;
    }

    if (contentType == 'application/x-www-form-urlencoded') {
      _parsedBody = Uri.splitQueryString(utf8.decode(bodyBytes));
      return _parsedBody;
    }

    if (contentType.startsWith('text/')) {
      _parsedBody = utf8.decode(bodyBytes);
      return _parsedBody;
    }

    _parsedBody = bodyBytes;
    return _parsedBody;
  }

  /// Returns a merged view of multipart form fields and uploaded files.
  ///
  /// Keys pointing to files expose `List<MultipartFile>` while standard
  /// fields expose `String` values. For non-multipart requests this resolves
  /// to an empty map.
  Future<Map<String, dynamic>> get formData async {
    if (_formDataCache != null) {
      return _formDataCache!;
    }

    final payload = await _ensureMultipartPayload();
    final combined = <String, dynamic>{};
    combined.addAll(payload.fields);
    combined.addAll(payload.files);
    _formDataCache = Map.unmodifiable(combined);
    return _formDataCache!;
  }

  /// Creates a request wrapper, bootstrapping session state from the incoming
  /// cookie (or generating a new session identifier when absent).
  factory Request.from(
    HttpRequest httpRequest, {
    required GetIt container,
  }) {
    Cookie? sessionCookie;
    bool isSessionNew = false;

    try {
      sessionCookie = httpRequest.cookies
          .firstWhere((cookie) => cookie.name == _sessionCookieName);
    } on StateError {
      sessionCookie = Cookie(_sessionCookieName, _generateSessionId());
      isSessionNew = true;
    }

    final session = Session(sessionCookie!.value);

    return Request(httpRequest, session, container, isSessionNew: isSessionNew);
  }

  static String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }

  /// Indicates whether a fresh session identifier was generated for this
  /// request (and therefore needs to be persisted back via response cookies).
  bool get isNewSession => _isSessionNew;

  Future<Map<String, List<MultipartFile>>> get files async {
    final payload = await _ensureMultipartPayload();
    return payload.files;
  }

  // Helper method to read stream fully into a list of bytes to prevent multiple listens
  static Future<List<int>> consolidateBytes(Stream<List<int>> stream) async {
    final buffer = BytesBuilder();
    await for (final chunk in stream) {
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  }

  Future<Uint8List> _ensureBodyBytes() {
    final existing = _bodyBytesFuture;
    if (existing != null) {
      return existing;
    }

    final future = () async {
      final buffer = BytesBuilder();
      await for (final chunk in httpRequest) {
        buffer.add(chunk);
      }
      return buffer.takeBytes();
    }();

    _bodyBytesFuture = future;
    return future;
  }

  Future<_FormDataPayload> _ensureMultipartPayload() async {
    if (_multipartPayload != null) {
      return _multipartPayload!;
    }

    final contentType = headers.contentType;
    if (contentType?.mimeType != 'multipart/form-data') {
      _multipartPayload = _FormDataPayload.empty;
      _formDataCache = const {};
      return _multipartPayload!;
    }

    final boundary = contentType!.parameters['boundary'];
    if (boundary == null || boundary.isEmpty) {
      _multipartPayload = _FormDataPayload.empty;
      _formDataCache = const {};
      return _multipartPayload!;
    }

    final transformer = MimeMultipartTransformer(boundary);
    final bodyBytes = await _ensureBodyBytes();
    final stream = Stream<List<int>>.fromIterable(<List<int>>[bodyBytes]);
    final parts = await transformer.bind(stream).toList();

    final fieldData = <String, String>{};
    final fileData = <String, List<MultipartFile>>{};

    for (final part in parts) {
      final contentDisposition = part.headers['content-disposition'];
      if (contentDisposition == null) {
        continue;
      }

      final nameMatch =
          RegExp(r'name="([^"]*)"').firstMatch(contentDisposition);
      if (nameMatch == null) {
        continue;
      }

      final name = nameMatch.group(1)!;
      final filenameMatch =
          RegExp(r'filename="([^"]*)"').firstMatch(contentDisposition);
      final bytes = Uint8List.fromList(await consolidateBytes(part));

      if (filenameMatch != null) {
        final filename = filenameMatch.group(1)!;
        final filesForField =
            fileData.putIfAbsent(name, () => <MultipartFile>[]);
        filesForField.add(
          MultipartFile.fromBytes(
            name,
            bytes,
            filename: filename,
          ),
        );
      } else {
        fieldData[name] = utf8.decode(bytes);
      }
    }

    _multipartPayload = _FormDataPayload(fieldData, fileData);
    final combined = <String, dynamic>{};
    combined.addAll(_multipartPayload!.fields);
    combined.addAll(_multipartPayload!.files);
    _formDataCache = Map.unmodifiable(combined);
    return _multipartPayload!;
  }

  static const String _sessionCookieName = 'sessionId';

  /// Public accessor for the name of the framework-managed session cookie.
  static const String sessionCookieName = _sessionCookieName;
}

class Session {
  final String id;
  final Map<String, dynamic> data = {};

  Session(this.id);
}

class _FormDataPayload {
  _FormDataPayload(
      Map<String, String> fields, Map<String, List<MultipartFile>> files)
      : fields = Map.unmodifiable(fields),
        files = Map.unmodifiable(
          files.map(
            (key, value) => MapEntry(key, List.unmodifiable(value)),
          ),
        );

  static final _FormDataPayload empty =
      _FormDataPayload(<String, String>{}, <String, List<MultipartFile>>{});

  final Map<String, String> fields;
  final Map<String, List<MultipartFile>> files;

  bool get hasFiles => files.isNotEmpty;
  bool get isEmpty => fields.isEmpty && files.isEmpty;
}
