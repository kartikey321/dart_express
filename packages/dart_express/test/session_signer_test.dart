import 'package:dart_express/dart_express.dart';
import 'package:test/test.dart';

void main() {
  group('SessionSigner', () {
    late SessionSigner signer;
    const testSecret =
        'this-is-a-very-secure-secret-key-with-32-plus-characters';

    setUp(() {
      signer = SessionSigner(testSecret);
    });

    group('constructor', () {
      test('accepts valid secret (32+ characters)', () {
        expect(() => SessionSigner(testSecret), returnsNormally);
      });

      test('throws on empty secret', () {
        expect(
          () => SessionSigner(''),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('throws on short secret (< 32 characters)', () {
        expect(
          () => SessionSigner('short-secret'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('at least 32 characters'),
          )),
        );
      });

      test('accepts exactly 32 character secret', () {
        final secret32 = 'a' * 32;
        expect(() => SessionSigner(secret32), returnsNormally);
      });
    });

    group('sign', () {
      test('returns signed value with correct format', () {
        final sessionId = 'test-session-123';
        final signed = signer.sign(sessionId);

        expect(signed, contains('.'));
        expect(signed.split('.').length, equals(2));
        expect(signed.startsWith(sessionId), isTrue);
      });

      test('generates consistent signatures for same input', () {
        final sessionId = 'consistent-session';
        final signed1 = signer.sign(sessionId);
        final signed2 = signer.sign(sessionId);

        expect(signed1, equals(signed2));
      });

      test('generates different signatures for different inputs', () {
        final signed1 = signer.sign('session-1');
        final signed2 = signer.sign('session-2');

        expect(signed1, isNot(equals(signed2)));
      });

      test('handles empty session ID', () {
        final signed = signer.sign('');
        expect(signed, contains('.'));
      });

      test('handles special characters', () {
        final sessionId = 'session-with-special!@#\$%^&*()';
        final signed = signer.sign(sessionId);
        expect(signed, contains(sessionId));
      });

      test('handles unicode characters', () {
        final sessionId = 'session-日本語-🎉';
        final signed = signer.sign(sessionId);
        expect(signed, contains(sessionId));
      });
    });

    group('verify', () {
      test('verifies valid signed value', () {
        final sessionId = 'valid-session';
        final signed = signer.sign(sessionId);
        final verified = signer.verify(signed);

        expect(verified, equals(sessionId));
      });

      test('returns null for tampered session ID', () {
        final sessionId = 'original-session';
        final signed = signer.sign(sessionId);
        final tampered = signed.replaceFirst(sessionId, 'tampered-session');
        final verified = signer.verify(tampered);

        expect(verified, isNull);
      });

      test('returns null for tampered signature', () {
        final sessionId = 'session-123';
        final signed = signer.sign(sessionId);
        final parts = signed.split('.');
        final tamperedSig = parts[1].substring(0, parts[1].length - 1) + 'x';
        final tampered = '${parts[0]}.$tamperedSig';
        final verified = signer.verify(tampered);

        expect(verified, isNull);
      });

      test('returns null for invalid format (no dot)', () {
        final verified = signer.verify('invalid-format-no-dot');
        expect(verified, isNull);
      });

      test('returns null for invalid format (multiple dots)', () {
        final verified = signer.verify('session.sig.extra');
        expect(verified, isNull);
      });

      test('returns null for empty string', () {
        final verified = signer.verify('');
        expect(verified, isNull);
      });

      test('returns null when signed with different secret', () {
        final sessionId = 'cross-secret-session';
        final signed = signer.sign(sessionId);

        final differentSigner = SessionSigner(
          'different-secret-key-with-32-plus-chars',
        );
        final verified = differentSigner.verify(signed);

        expect(verified, isNull);
      });

      test('verifies signature with special characters', () {
        final sessionId = 'special!@#\$%';
        final signed = signer.sign(sessionId);
        final verified = signer.verify(signed);

        expect(verified, equals(sessionId));
      });

      test('verifies signature with unicode', () {
        final sessionId = 'unicode-テスト-🔐';
        final signed = signer.sign(sessionId);
        final verified = signer.verify(signed);

        expect(verified, equals(sessionId));
      });
    });

    group('security properties', () {
      test('different secrets produce different signatures', () {
        final sessionId = 'same-session-id';
        final signer1 = SessionSigner('secret-one-with-32-characters-min');
        final signer2 = SessionSigner('secret-two-with-32-characters-min');

        final signed1 = signer1.sign(sessionId);
        final signed2 = signer2.sign(sessionId);

        expect(signed1, isNot(equals(signed2)));
      });

      test('signature is deterministic (HMAC property)', () {
        final sessionId = 'deterministic-test';
        final signatures = List.generate(100, (_) => signer.sign(sessionId));

        expect(signatures.toSet().length, equals(1));
      });

      test('signature length is consistent', () {
        final lengths = <int>{};
        for (var i = 0; i < 10; i++) {
          final signed = signer.sign('session-$i');
          final signature = signed.split('.')[1];
          lengths.add(signature.length);
        }

        expect(lengths.length, equals(1),
            reason: 'All signatures should have same length');
      });

      test('cannot forge signature without secret', () {
        final sessionId = 'protected-session';
        final fakeSignature = 'a' * 64; // SHA256 hex is 64 chars
        final forged = '$sessionId.$fakeSignature';

        final verified = signer.verify(forged);
        expect(verified, isNull);
      });
    });

    group('edge cases', () {
      test('handles very long session IDs', () {
        final longId = 'x' * 10000;
        final signed = signer.sign(longId);
        final verified = signer.verify(signed);

        expect(verified, equals(longId));
      });

      test('handles session ID that looks like signature', () {
        final sessionId = 'a1b2c3d4e5f6' * 5;
        final signed = signer.sign(sessionId);
        final verified = signer.verify(signed);

        expect(verified, equals(sessionId));
      });

      test('handles session ID with dots', () {
        // Session IDs shouldn't have dots, but test the behavior
        final sessionId = 'session.with.dots';
        final signed = signer.sign(sessionId);

        // This will fail verification due to format
        final verified = signer.verify(signed);
        // The signature will be wrong because split('.') breaks it
        expect(verified, isNull);
      });
    });
  });
}
