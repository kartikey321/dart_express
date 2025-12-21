import 'dart:async';

/// Abstract interface for session persistence backends.
///
/// Implement this interface to create custom session stores using
/// Redis, PostgreSQL, MongoDB, or any other persistence layer.
///
/// ## Built-in Implementations
/// - [MemorySessionStore]: In-memory storage (default, not for production multi-instance)
///
/// ## Example: Redis Implementation
/// ```dart
/// class RedisSessionStore implements SessionStore {
///   final RedisConnection redis;
///
///   RedisSessionStore(this.redis);
///
///   @override
///   Future<Map<String, dynamic>?> load(String sessionId) async {
///     final data = await redis.get('session:$sessionId');
///     return data != null ? jsonDecode(data) : null;
///   }
///
///   @override
///   Future<void> save(String sessionId, Map<String, dynamic> data, {Duration? ttl}) async {
///     final value = jsonEncode(data);
///     if (ttl != null) {
///       await redis.setex('session:$sessionId', ttl.inSeconds, value);
///     } else {
///       await redis.set('session:$sessionId', value);
///     }
///   }
///
///   @override
///   Future<void> destroy(String sessionId) async {
///     await redis.del('session:$sessionId');
///   }
/// }
/// ```
abstract class SessionStore {
  /// Loads session data for the given [sessionId].
  ///
  /// Returns a map of session data, or `null` if the session doesn't exist
  /// or has expired.
  ///
  /// **Implementation Notes**:
  /// - Return a new map instance (don't return internal references)
  /// - Handle expired sessions by returning null
  /// - Should be idempotent (calling multiple times returns same data)
  Future<Map<String, dynamic>?> load(String sessionId);

  /// Saves session data for the given [sessionId].
  ///
  /// Parameters:
  /// - [sessionId]: Unique session identifier
  /// - [data]: Session data to persist
  /// - [ttl]: Time-to-live for the session (optional)
  ///
  /// **Implementation Notes**:
  /// - Store a copy of data (don't store references)
  /// - If [ttl] is provided, session should expire after that duration
  /// - Should handle concurrent writes safely
  /// - Should be atomic (all-or-nothing)
  Future<void> save(
    String sessionId,
    Map<String, dynamic> data, {
    Duration? ttl,
  });

  /// Destroys the session with the given [sessionId].
  ///
  /// After calling this, [load] should return `null` for this session.
  ///
  /// **Implementation Notes**:
  /// - Should be idempotent (destroying non-existent session is OK)
  /// - Should clean up all related data
  Future<void> destroy(String sessionId);

  /// Extends the lifetime of the session without modifying data.
  ///
  /// Useful for implementing sliding session expiration where sessions
  /// automatically extend when users are active.
  ///
  /// Parameters:
  /// - [sessionId]: Session to touch
  /// - [ttl]: New time-to-live duration
  ///
  /// **Implementation Notes**:
  /// - If session doesn't exist, this is a no-op
  /// - Only updates expiration timestamp, not data
  /// - Optional to implement (can be no-op if store auto-expires)
  Future<void> touch(String sessionId, {Duration? ttl}) async {
    // Default implementation: no-op
    // Override if your store supports TTL extension
  }

  /// Cleans up expired sessions.
  ///
  /// Called periodically to remove stale sessions. Not needed for stores
  /// that automatically expire sessions (like Redis).
  ///
  /// **Implementation Notes**:
  /// - Can be a no-op if store handles expiration automatically
  /// - Should be safe to run concurrently
  /// - Should not block for long periods
  Future<void> cleanup() async {
    // Default implementation: no-op
    // Override if your store needs manual cleanup
  }

  /// Disposes resources held by this store.
  ///
  /// Called when the server shuts down. Use this to close database
  /// connections, cancel timers, etc.
  Future<void> dispose() async {
    // Default implementation: no-op
    // Override if your store needs cleanup
  }
}
