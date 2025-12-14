import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Provides session cookie signing and verification using HMAC-SHA256.
///
/// Session cookies are signed with a secret key to prevent tampering and
/// ensure authenticity. The signature is appended to the session ID using
/// the format: `sessionId.signature`.
///
/// ## Security
///
/// - Uses **HMAC-SHA256** for cryptographic signing
/// - Requires **32+ character secret** for security
/// - **Constant-time comparison** prevents timing attacks
/// - Secrets should be stored in environment variables
///
/// ## Usage
///
/// ```dart
/// // Generate a secret (do this once, store in env)
/// // openssl rand -base64 48
/// final secret = Platform.environment['SESSION_SECRET']!;
/// final signer = SessionSigner(secret);
///
/// // Sign a session ID
/// final sessionId = 'abc123';
/// final signed = signer.sign(sessionId);
/// // Result: "abc123.a1b2c3d4e5..."
///
/// // Verify and extract
/// final verified = signer.verify(signed);
/// if (verified != null) {
///   print('Valid session: $verified');
/// } else {
///   print('Invalid or tampered signature!');
/// }
/// ```
///
/// ## Format
///
/// Signed values use dot notation: `value.signature`
/// Example: `sess_uuid.3a8f9c2e1d...`
///
/// See also:
/// - [DartExpress.sessionSecret] for framework integration
/// - [SessionStore] for session persistence
class SessionSigner {
  /// The secret key used for HMAC-SHA256 signing.
  ///
  /// Must be at least 32 characters. Generate with:
  /// ```bash
  /// openssl rand -base64 48
  /// ```
  final String secret;

  final String _separator = '.';

  /// Creates a new session signer with the provided [secret].
  ///
  /// Throws [ArgumentError] if the secret is empty or less than 32 characters.
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
  /// The returned value has the format: `sessionId.signature`
  ///
  /// ## Example
  ///
  /// ```dart
  /// final signed = signer.sign('session_abc123');
  /// // Returns: "session_abc123.a1b2c3d4e5f6..."
  /// ```
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
