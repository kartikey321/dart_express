import 'dart:collection';

abstract class RateLimitStore {
  Future<bool> increment(String key, int maxRequests, Duration window);
  Future<void> reset(String key);
}

/// In-memory store for rate limiter
class MemoryRateLimitStore implements RateLimitStore {
  final HashMap<String, List<int>> _store = HashMap();

  @override
  Future<bool> increment(String key, int maxRequests, Duration window) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowStart = now - window.inMilliseconds;

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
    //need discussion
    if (_store.containsKey(key)) {
      _store.remove(key);
    }
  }
}
