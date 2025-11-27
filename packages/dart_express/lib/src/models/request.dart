import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_express/dart_express.dart';
import 'package:get_it/get_it.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

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
  final int maxBodySize;
  final int maxFileSize;
  Object? _parsedBody;
  Future<Uint8List>? _bodyBytesFuture;
  _FormDataPayload? _multipartPayload;
  Map<String, dynamic>? _formDataCache;
  final bool _isSessionNew;
  List<Cookie> cookies = [];

  Request(
    this.httpRequest,
    this.session,
    this.container, {
    bool isSessionNew = false,
    this.maxBodySize = 10 * 1024 * 1024,
    this.maxFileSize = 100 * 1024 * 1024,
  }) : _isSessionNew = isSessionNew {
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
    int maxBodySize = 10 * 1024 * 1024,
    int maxFileSize = 100 * 1024 * 1024,
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

    return Request(
      httpRequest,
      session,
      container,
      isSessionNew: isSessionNew,
      maxBodySize: maxBodySize,
      maxFileSize: maxFileSize,
    );
  }

  /// Generate a cryptographically secure session ID using UUID v4
  static String _generateSessionId() {
    return const Uuid().v4();
  }

  /// Indicates whether a fresh session identifier was generated for this
  /// request (and therefore needs to be persisted back via response cookies).
  bool get isNewSession => _isSessionNew;

  Future<Map<String, List<MultipartFile>>> get files async {
    final payload = await _ensureMultipartPayload();
    return payload.files;
  }

  // Helper method to read stream fully into a list of bytes to prevent multiple listens
  Future<List<int>> consolidateBytes(Stream<List<int>> stream,
      {int? sizeLimit}) async {
    final buffer = BytesBuilder();
    var totalSize = 0;
    final limit = sizeLimit ?? maxFileSize;

    await for (final chunk in stream) {
      totalSize += chunk.length;

      if (totalSize > limit) {
        throw HttpError(413, 'File too large');
      }

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
      var totalSize = 0;

      await for (final chunk in httpRequest) {
        totalSize += chunk.length;

        if (totalSize > maxBodySize) {
          // Drain remaining stream to prevent connection issues
          await httpRequest.drain();
          throw HttpError(413, 'Payload Too Large');
        }

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

      if (filenameMatch != null) {
        // This is a file upload - check file size limit
        final filename = filenameMatch.group(1)!;
        final bytes =
            Uint8List.fromList(await consolidateBytes(part, sizeLimit: maxFileSize));

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
        // Regular form field
        final bytes = Uint8List.fromList(await consolidateBytes(part));
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
