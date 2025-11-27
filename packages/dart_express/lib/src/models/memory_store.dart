import 'dart:async';
import 'dart:collection';

abstract class RateLimitStore {
  Future<bool> increment(String key, int maxRequests, Duration window);
  Future<void> reset(String key);
}

/// In-memory store for rate limiter with automatic cleanup
class MemoryRateLimitStore implements RateLimitStore {
  final HashMap<String, List<int>> _store = HashMap();
  final HashMap<String, int> _lastAccess = HashMap();
  Timer? _cleanupTimer;
  final Duration _cleanupInterval;
  final Duration _keyExpiry;

  MemoryRateLimitStore({
    Duration cleanupInterval = const Duration(minutes: 10),
    Duration keyExpiry = const Duration(hours: 1),
  })  : _cleanupInterval = cleanupInterval,
        _keyExpiry = keyExpiry {
    _startCleanup();
  }

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) => _cleanup());
  }

  void _cleanup() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryThreshold = now - _keyExpiry.inMilliseconds;
    final keysToRemove = <String>[];

    for (final entry in _lastAccess.entries) {
      if (entry.value < expiryThreshold) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _store.remove(key);
      _lastAccess.remove(key);
    }
  }

  @override
  Future<bool> increment(String key, int maxRequests, Duration window) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowStart = now - window.inMilliseconds;

    _lastAccess[key] = now; // Track last access for cleanup

    _store.putIfAbsent(key, () => []);

    _store[key]!.removeWhere((timestamp) => timestamp < windowStart);

    if (_store[key]!.length >= maxRequests) {
      return false; // Rate limit exceeded
    }

    _store[key]!.add(now);
    return true;
  }

  @override
  Future<void> reset(String key) async {
    if (_store.containsKey(key)) {
      _store.remove(key);
      _lastAccess.remove(key);
    }
  }

  /// Dispose the cleanup timer
  void dispose() {
    _cleanupTimer?.cancel();
  }
}
