import 'package:dart_express/dart_express.dart';
import 'package:test/test.dart';

void main() {
  group('MemorySessionStore', () {
    late MemorySessionStore store;

    setUp(() {
      store = MemorySessionStore(
        defaultTTL: Duration(hours: 1),
        cleanupInterval: Duration(milliseconds: 100),
      );
    });

    tearDown(() async {
      await store.dispose();
    });

    group('save and load', () {
      test('saves and loads session data', () async {
        final sessionId = 'test-session-1';
        final data = {'userId': '123', 'username': 'alice'};

        await store.save(sessionId, data);
        final loaded = await store.load(sessionId);

        expect(loaded, equals(data));
      });

      test('returns null for non-existent session', () async {
        final loaded = await store.load('non-existent-session');
        expect(loaded, isNull);
      });

      test('overwrites existing session data', () async {
        final sessionId = 'overwrite-test';
        await store.save(sessionId, {'version': 1});
        await store.save(sessionId, {'version': 2});

        final loaded = await store.load(sessionId);
        expect(loaded, equals({'version': 2}));
      });

      test('stores independent session data', () async {
        await store.save('session-1', {'user': 'alice'});
        await store.save('session-2', {'user': 'bob'});

        final session1 = await store.load('session-1');
        final session2 = await store.load('session-2');

        expect(session1!['user'], equals('alice'));
        expect(session2!['user'], equals('bob'));
      });

      test('handles empty session data', () async {
        final sessionId = 'empty-session';
        await store.save(sessionId, {});

        final loaded = await store.load(sessionId);
        expect(loaded, equals({}));
      });

      test('handles complex nested data', () async {
        final sessionId = 'complex-session';
        final data = {
          'user': {'id': 123, 'name': 'Alice'},
          'preferences': ['dark-mode', 'notifications'],
          'metadata': {
            'createdAt': '2024-01-01',
            'lastSeen': '2024-01-02',
          },
        };

        await store.save(sessionId, data);
        final loaded = await store.load(sessionId);

        expect(loaded, equals(data));
      });

      test('returns copy of data (not reference)', () async {
        final sessionId = 'reference-test';
        final original = {'counter': 0};

        await store.save(sessionId, original);
        original['counter'] = 999;

        final loaded = await store.load(sessionId);
        expect(loaded!['counter'], equals(0));
      });
    });

    group('destroy', () {
      test('removes session data', () async {
        final sessionId = 'destroy-test';
        await store.save(sessionId, {'data': 'value'});

        await store.destroy(sessionId);
        final loaded = await store.load(sessionId);

        expect(loaded, isNull);
      });

      test('destroy is idempotent', () async {
        final sessionId = 'idempotent-test';
        await store.save(sessionId, {'data': 'value'});

        await store.destroy(sessionId);
        await store.destroy(sessionId);
        await store.destroy(sessionId);

        final loaded = await store.load(sessionId);
        expect(loaded, isNull);
      });

      test('destroy non-existent session does not throw', () async {
        expect(
          () async => await store.destroy('non-existent'),
          returnsNormally,
        );
      });
    });

    group('TTL and expiration', () {
      test('session expires after TTL', () async {
        final shortStore = MemorySessionStore(
          defaultTTL: Duration(milliseconds: 50),
        );

        final sessionId = 'expiring-session';
        await shortStore.save(sessionId, {'data': 'value'});

        // Immediately should exist
        var loaded = await shortStore.load(sessionId);
        expect(loaded, isNotNull);

        // Wait for expiration
        await Future.delayed(Duration(milliseconds: 100));

        loaded = await shortStore.load(sessionId);
        expect(loaded, isNull);

        await shortStore.dispose();
      });

      test('custom TTL overrides default', () async {
        final sessionId = 'custom-ttl';
        await store.save(
          sessionId,
          {'data': 'value'},
          ttl: Duration(milliseconds: 50),
        );

        // Immediately should exist
        var loaded = await store.load(sessionId);
        expect(loaded, isNotNull);

        // Wait for custom TTL to expire
        await Future.delayed(Duration(milliseconds: 100));

        loaded = await store.load(sessionId);
        expect(loaded, isNull);
      });

      test('sessions with longer TTL persist', () async {
        final sessionId = 'long-ttl';
        await store.save(
          sessionId,
          {'data': 'value'},
          ttl: Duration(hours: 24),
        );

        await Future.delayed(Duration(milliseconds: 100));

        final loaded = await store.load(sessionId);
        expect(loaded, isNotNull);
      });

      test('updating session refreshes TTL', () async {
        final shortStore = MemorySessionStore(
          defaultTTL: Duration(milliseconds: 100),
        );

        final sessionId = 'refresh-ttl';
        await shortStore.save(sessionId, {'version': 1});

        // Wait halfway through TTL
        await Future.delayed(Duration(milliseconds: 60));

        // Update session (refreshes TTL)
        await shortStore.save(sessionId, {'version': 2});

        // Wait another 60ms (would expire old TTL)
        await Future.delayed(Duration(milliseconds: 60));

        // Should still exist due to refresh
        final loaded = await shortStore.load(sessionId);
        expect(loaded, isNotNull);
        expect(loaded!['version'], equals(2));

        await shortStore.dispose();
      });
    });

    group('cleanup', () {
      test('cleanup timer removes expired sessions', () async {
        final cleanupStore = MemorySessionStore(
          defaultTTL: Duration(milliseconds: 50),
          cleanupInterval: Duration(milliseconds: 100),
        );

        // Create multiple sessions
        await cleanupStore.save('session-1', {'data': '1'});
        await cleanupStore.save('session-2', {'data': '2'});
        await cleanupStore.save('session-3', {'data': '3'});

        // Wait for expiration and cleanup
        await Future.delayed(Duration(milliseconds: 200));

        // All should be cleaned up
        expect(await cleanupStore.load('session-1'), isNull);
        expect(await cleanupStore.load('session-2'), isNull);
        expect(await cleanupStore.load('session-3'), isNull);

        await cleanupStore.dispose();
      });

      test('cleanup preserves non-expired sessions', () async {
        final cleanupStore = MemorySessionStore(
          defaultTTL: Duration(hours: 1),
          cleanupInterval: Duration(milliseconds: 50),
        );

        await cleanupStore.save('long-session', {'data': 'persist'});

        // Wait for cleanup cycle
        await Future.delayed(Duration(milliseconds: 100));

        // Should still exist
        final loaded = await cleanupStore.load('long-session');
        expect(loaded, isNotNull);

        await cleanupStore.dispose();
      });
    });

    group('dispose', () {
      test('completes without errors', () async {
        final disposableStore = MemorySessionStore(
          cleanupInterval: Duration(milliseconds: 50),
        );

        await disposableStore.save('session', {'data': 'value'});

        // Dispose should complete without errors
        await disposableStore.dispose();
      });

      test('dispose is idempotent', () async {
        expect(
          () async {
            await store.dispose();
            await store.dispose();
            await store.dispose();
          },
          returnsNormally,
        );
      });
    });

    group('concurrent access', () {
      test('handles concurrent saves', () async {
        final sessionId = 'concurrent-saves';
        final futures = <Future>[];

        for (var i = 0; i < 10; i++) {
          futures.add(store.save(sessionId, {'version': i}));
        }

        await Future.wait(futures);

        final loaded = await store.load(sessionId);
        expect(loaded, isNotNull);
        expect(loaded!['version'], isA<int>());
      });

      test('handles concurrent reads', () async {
        final sessionId = 'concurrent-reads';
        await store.save(sessionId, {'data': 'value'});

        final futures = <Future>[];
        for (var i = 0; i < 100; i++) {
          futures.add(store.load(sessionId));
        }

        final results = await Future.wait(futures);
        expect(results.every((r) => r != null), isTrue);
      });

      test('handles mixed read/write operations', () async {
        final futures = <Future>[];

        for (var i = 0; i < 50; i++) {
          futures.add(store.save('session-$i', {'index': i}));
          futures.add(store.load('session-${i ~/ 2}'));
        }

        await Future.wait(futures);

        // Verify some sessions exist
        final loaded = await store.load('session-25');
        expect(loaded, isNotNull);
      });
    });

    group('edge cases', () {
      test('handles very large session data', () async {
        final sessionId = 'large-data';
        final largeData = {
          'items': List.generate(1000, (i) => {'id': i, 'name': 'Item $i'}),
        };

        await store.save(sessionId, largeData);
        final loaded = await store.load(sessionId);

        expect(loaded, isNotNull);
        expect((loaded!['items'] as List).length, equals(1000));
      });

      test('handles special characters in session ID', () async {
        final sessionId = 'session-!@#\$%^&*()-=+[]{}';
        await store.save(sessionId, {'data': 'special'});

        final loaded = await store.load(sessionId);
        expect(loaded, isNotNull);
      });

      test('handles unicode in session data', () async {
        final data = {
          'name': '田中太郎',
          'emoji': '🎉🔐',
          'mixed': 'Hello世界',
        };

        await store.save('unicode-session', data);
        final loaded = await store.load('unicode-session');

        expect(loaded, equals(data));
      });
    });
  });
}
