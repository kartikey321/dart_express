import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fletch/fletch.dart';
import 'package:get_it/get_it.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

/// Represents an incoming HTTP request with convenient accessors for
/// common data like headers, query parameters, request body, and session.
///
/// Request objects are created by the framework and passed to route handlers.
/// The request body stream can only be consumed once, so repeated reads of
/// [body] or [formData] will return the cached value.
///
/// ## Example
///
/// ```dart
/// app.post('/users', (req, res) async {
///   // Access path parameters
///   final id = req.params['id'];
///
///   // Access query parameters
///   final filter = req.query['filter'];
///
///  // Access request body
///   final data = await req.body;
///
///   // Access session
///   req.session['userId'] = id;
/// });
/// ```
class Request {
  /// The underlying Dart HttpRequest.
  final HttpRequest httpRequest;

  /// Unique identifier for this request (UUID v4).
  final String requestId;

  /// Path parameters extracted from the route pattern.
  ///
  /// For route `/users/:id`, accessing `/users/123` gives `params['id'] == '123'`.
  Map<String, String> params = {};

  /// Query parameters from the URL.
  ///
  /// For URL `/search?q=dart&page=2`:
  /// - `query['q']` returns `'dart'`
  /// - `query['page']` returns `'2'`
  late final Map<String, String> query;

  /// Session for this request.
  ///
  /// Access session data with:
  /// ```dart
  /// req.session['key'] = 'value';
  /// final value = req.session['key'];
  /// ```
  final Session session;

  /// Dependency injection container for this request.
  final GetIt container;

  /// Maximum allowed request body size in bytes (default: 10MB).
  final int maxBodySize;

  /// Maximum allowed file upload size in bytes (default: 100MB).
  final int maxFileSize;

  /// Session signer for verifying cookie signatures.
  final SessionSigner? sessionSigner;

  Object? _parsedBody;
  Future<Uint8List>? _bodyBytesFuture;
  _FormDataPayload? _multipartPayload;
  Map<String, dynamic>? _formDataCache;
  final bool _isSessionNew;

  /// Parsed cookies from the Cookie header.
  List<Cookie> cookies = [];

  Request(
    this.httpRequest,
    this.session,
    this.requestId,
    this.container, {
    bool isSessionNew = false,
    this.maxBodySize = 10 * 1024 * 1024,
    this.maxFileSize = 100 * 1024 * 1024,
    this.sessionSigner,
  }) : _isSessionNew = isSessionNew {
    query = httpRequest.uri.queryParameters;
  }

  /// HTTP method (GET, POST, PUT, DELETE, etc.).
  String get method => httpRequest.method;

  /// Request URI with path and query parameters.
  Uri get uri => httpRequest.uri;

  /// HTTP request headers.
  HttpHeaders get headers => httpRequest.headers;

  /// Returns the parsed request body.
  ///
  /// Body is parsed based on Content-Type header:
  /// - `application/json` → Decoded JSON (Map or List)
  /// - `application/x-www-form-urlencoded` → Map(String, String)
  /// - `text/*` → String
  /// - Other → Uint8List (raw bytes)
  ///
  /// The body stream is consumed only once. Subsequent calls return cached value.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.post('/api/data', (req, res) async {
  ///   final body = await req.body;
  ///
  ///   if (body is Map) {
  ///     final name = body['name'];
  ///     res.json({'received': name});
  ///   }
  /// });
  /// ```
  ///
  /// Returns `null` if body is empty.
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
  ///
  /// If [sessionSigner] is provided, session cookies will be verified using
  /// HMAC-SHA256. Invalid signatures will be treated as if no session exists.
  factory Request.from(
    HttpRequest httpRequest, {
    required GetIt container,
    int maxBodySize = 10 * 1024 * 1024,
    int maxFileSize = 100 * 1024 * 1024,
    SessionSigner? sessionSigner,
    SessionStore? sessionStore,
  }) {
    Cookie? sessionCookie;
    bool isSessionNew = false;
    String sessionId;

    try {
      sessionCookie = httpRequest.cookies
          .firstWhere((cookie) => cookie.name == _sessionCookieName);

      // Verify signed session cookie if signer is available
      if (sessionSigner != null) {
        final verifiedId = sessionSigner.verify(sessionCookie.value);
        if (verifiedId != null) {
          sessionId = verifiedId;
        } else {
          // Invalid signature - generate new session
          sessionId = _generateSessionId();
          isSessionNew = true;
        }
      } else {
        // No signing - use cookie value as-is
        sessionId = sessionCookie.value;
      }
    } on StateError {
      // No session cookie found - create new session
      sessionId = _generateSessionId();
      isSessionNew = true;
    }

    final session = Session(sessionId, store: sessionStore);
    final requestId = httpRequest.headers.value('x-request-id') ??
        httpRequest.headers.value('x-correlation-id') ??
        _generateRequestId();

    return Request(
      httpRequest,
      session,
      requestId,
      container,
      isSessionNew: isSessionNew,
      maxBodySize: maxBodySize,
      maxFileSize: maxFileSize,
      sessionSigner: sessionSigner,
    );
  }

  /// Generate a cryptographically secure session ID using UUID v4
  static String _generateSessionId() {
    return const Uuid().v4();
  }

  static String _generateRequestId() {
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
      final iterator = StreamIterator<List<int>>(httpRequest);

      try {
        while (await iterator.moveNext()) {
          final chunk = iterator.current;
          totalSize += chunk.length;

          if (totalSize > maxBodySize) {
            // Consume and discard remaining bytes to keep the socket healthy.
            while (await iterator.moveNext()) {}
            throw HttpError(413, 'Payload Too Large');
          }

          buffer.add(chunk);
        }
      } finally {
        await iterator.cancel();
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
        final bytes = Uint8List.fromList(
            await consolidateBytes(part, sizeLimit: maxFileSize));

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

/// Represents a user session with optional persistent storage.
///
/// Sessions can be backed by a [SessionStore] for persistence across
/// server restarts and multi-instance deployments.
///
/// ## Usage
/// ```dart
/// // Access session data
/// final userId = req.session['userId'];
///
/// // Set session data
/// req.session['userId'] = '123';
/// req.session['username'] = 'john';
///
/// // Session is automatically saved after request completes
/// ```
class Session {
  final String id;
  final SessionStore? _store;
  Map<String, dynamic> _data = {};
  bool _isDirty = false;
  bool _isLoaded = false;

  Session(this.id, {SessionStore? store}) : _store = store {
    // If no store, mark as loaded since there's nothing to load
    if (store == null) {
      _isLoaded = true;
    }
  }

  /// Gets a value from the session.
  dynamic operator [](String key) => _data[key];

  /// Sets a value in the session and marks it as dirty.
  void operator []=(String key, dynamic value) {
    _data[key] = value;
    _isDirty = true;
  }

  /// Removes a key from the session.
  void remove(String key) {
    _data.remove(key);
    _isDirty = true;
  }

  /// Clears all session data.
  void clear() {
    _data.clear();
    _isDirty = true;
  }

  /// Returns an unmodifiable view of session data.
  Map<String, dynamic> get data => Map.unmodifiable(_data);

  /// Whether this session has unsaved changes.
  bool get isDirty => _isDirty;

  /// Loads session data from the store.
  ///
  /// This is automatically called when a request is processed.
  /// You rarely need to call this manually.
  Future<void> load() async {
    if (_store != null && !_isLoaded) {
      final loadedData = await _store.load(id);
      _data = loadedData ?? {};
      _isLoaded = true;
      _isDirty = false;
    }
  }

  /// Saves session data to the store if it has been modified.
  ///
  /// This is automatically called after a request completes.
  /// You can call it manually if you need to ensure data is persisted.
  ///
  /// Parameters:
  /// - [ttl]: Optional time-to-live for the session
  Future<void> save({Duration? ttl}) async {
    if (_store != null && _isDirty) {
      await _store.save(id, _data, ttl: ttl);
      _isDirty = false;
    }
  }

  /// Destroys this session, removing all data from the store.
  ///
  /// After calling this, the session ID becomes invalid and a new
  /// session will be created on the next request.
  Future<void> destroy() async {
    if (_store != null) {
      await _store.destroy(id);
    }
    _data.clear();
    _isDirty = false;
  }

  // Removed regenerate() method - session ID is final and can't be changed.
  // To regenerate session for security (e.g., after login), create a new
  // session by destroying the current one and letting the framework create
  // a new one on the next request.
  //
  // Example:
  //   await req.session.destroy();
  //   res.clearCookie(Request.sessionCookieName);
  //   // Next request will get a new session
}

class _FormDataPayload {
  _FormDataPayload(
      Map<String, String> fields, Map<String, List<MultipartFile>> files)
      : fields = Map.unmodifiable(Map<String, String>.from(fields)),
        files = Map.unmodifiable(
          files.map(
            (key, value) =>
                MapEntry(key, List<MultipartFile>.unmodifiable(value)),
          ),
        );

  static final _FormDataPayload empty =
      _FormDataPayload(<String, String>{}, <String, List<MultipartFile>>{});

  final Map<String, String> fields;
  final Map<String, List<MultipartFile>> files;

  bool get hasFiles => files.isNotEmpty;
  bool get isEmpty => fields.isEmpty && files.isEmpty;
}
