import 'dart:async';
import 'dart:io';

/// A sink for sending Server-Sent Events (SSE) to a client.
///
/// SSE allows servers to push real-time updates to clients over HTTP.
///
/// ## Example
///
/// ```dart
/// app.get('/events', (req, res) async {
///   res.sse((sink) async {
///     sink.sendEvent('Hello from SSE!');
///     sink.sendEvent('Update 1', event: 'update');
///     sink.sendEvent(jsonEncode({'data': 'value'}), id: '123');
///     await Future.delayed(Duration(seconds: 30));
///     sink.close();
///   });
/// });
/// ```
class SSESink {
  final HttpResponse _response;
  bool _closed = false;
  Timer? _keepAliveTimer;

  /// Whether this sink has been closed.
  bool get isClosed => _closed;

  SSESink(this._response);

  /// Sends an SSE event to the client.
  ///
  /// ## Parameters
  ///
  /// - [data]: The event data (will be sent as-is, use jsonEncode for objects)
  /// - [event]: Optional event type (defaults to 'message')
  /// - [id]: Optional event ID for client-side tracking
  /// - [retry]: Optional reconnection time in milliseconds
  ///
  /// ## Example
  ///
  /// ```dart
  /// await sink.sendEvent('Simple message');
  /// await sink.sendEvent('Custom event', event: 'notification');
  /// await sink.sendEvent(jsonEncode({'user': 'Alice'}), id: '42');
  /// ```
  Future<void> sendEvent(
    String data, {
    String? event,
    String? id,
    int? retry,
  }) async {
    if (_closed) {
      throw StateError('Cannot send event on closed SSE sink');
    }

    try {
      if (id != null) {
        _response.write('id: $id\n');
      }
      if (event != null) {
        _response.write('event: $event\n');
      }
      if (retry != null) {
        _response.write('retry: $retry\n');
      }

      // Split data by newlines and prefix each with 'data: '
      final lines = data.split('\n');
      for (final line in lines) {
        _response.write('data: $line\n');
      }

      // Empty line to signal end of event
      _response.write('\n');

      // Flush immediately to ensure event is sent
      await _response.flush();
    } catch (e) {
      // Connection may have been closed by client
      _closed = true;
      rethrow;
    }
  }

  /// Sends a comment (ignored by clients, useful for keeping connection alive).
  ///
  /// ## Example
  ///
  /// ```dart
  /// await sink.sendComment('Keep-alive ping');
  /// ```
  Future<void> sendComment(String comment) async {
    if (_closed) return;

    try {
      _response.write(': $comment\n\n');
      await _response.flush(); // Flush keep-alive immediately
    } catch (e) {
      _closed = true;
    }
  }

  /// Starts automatic keep-alive pings to prevent connection timeout.
  ///
  /// Sends a comment every [interval] to keep the connection alive.
  ///
  /// ## Example
  ///
  /// ```dart
  /// sink.startKeepAlive(Duration(seconds: 15));
  /// ```
  void startKeepAlive(Duration interval) {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(interval, (_) {
      if (!_closed) {
        unawaited(sendComment('keep-alive'));
      }
    });
  }

  /// Stops automatic keep-alive pings.
  void stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Closes the SSE connection.
  ///
  /// After calling this, no more events can be sent.
  Future<void> close() async {
    if (_closed) return;

    _closed = true;
    _keepAliveTimer?.cancel();
    await _response.close();
  }
}
