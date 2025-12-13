import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Provides session cookie signing and verification using HMAC-SHA256.
///
/// Session cookies are signed to prevent tampering. The signature is appended
/// to the session ID using the format: `sessionId.signature`.
class SessionSigner {
  final String secret;
  final String _separator = '.';

  SessionSigner(this.secret) {
    if (secret.isEmpty) {
      throw ArgumentError('Session secret cannot be empty');
    }
    if (secret.length < 32) {
      throw ArgumentError(
          'Session secret must be at least 32 characters for security');
    }
  }

  /// Signs a session ID and returns the signed value.
  ///
  /// Format: `sessionId.signature`
  String sign(String sessionId) {
    final signature = _generateSignature(sessionId);
    return '$sessionId$_separator$signature';
  }

  /// Verifies and extracts the session ID from a signed value.
  ///
  /// Returns the original session ID if the signature is valid, or null if
  /// the signature is invalid or the format is incorrect.
  String? verify(String signedValue) {
    final parts = signedValue.split(_separator);
    if (parts.length != 2) {
      return null; // Invalid format
    }

    final sessionId = parts[0];
    final providedSignature = parts[1];
    final expectedSignature = _generateSignature(sessionId);

    // Use constant-time comparison to prevent timing attacks
    if (_secureCompare(providedSignature, expectedSignature)) {
      return sessionId;
    }

    return null; // Invalid signature
  }

  String _generateSignature(String value) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(value);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  /// Constant-time string comparison to prevent timing attacks
  bool _secureCompare(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return result == 0;
  }
}
