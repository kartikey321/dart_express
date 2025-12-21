# Changelog

All notable changes to fletch will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2025-01-22

### 💥 BREAKING CHANGES - Package Rename

**The package has been renamed from `dart_express` to `fletch`**

- **Package name**: `dart_express` → `fletch`
- **Main class**: `DartExpress` → `Fletch`
- **Import path**: `package:dart_express` → `package:fletch`
- **Repository**: Moved to `https://github.com/kartikey321/fletch`

### Migration Guide

To migrate from dart_express to fletch:

1. **Update `pubspec.yaml`**:
   ```yaml
   dependencies:
     fletch: ^1.1.0  # was: dart_express: ^1.0.0
   ```

2. **Update imports**:
   ```dart
   import 'package:fletch/fletch.dart';  // was: package:dart_express/dart_express.dart
   ```

3. **Update class usage**:
   ```dart
   final app = Fletch();  // was: DartExpress()
   ```

4. Run `dart pub get` to update dependencies

### Documentation
- **New documentation site**: https://docs.fletch.mahawarkartikey.in/
- Updated all examples and guides
- Improved API documentation

### Note
All functionality remains the same. This is purely a rename for better branding and pub.dev availability.

---

## [1.0.0] - 2024-12-13

### 🔒 Security Enhancements
- **Added HMAC-SHA256 session signing**: Session cookies are now cryptographically signed to prevent tampering
- **Changed session cookie defaults**: Now use `secure: true`, `httpOnly: true`, `SameSite: Lax` by default
- **Added constant-time signature comparison**: Protection against timing attacks
- **Fixed rate limiter memory leak**: Cleanup timers now properly disposed on shutdown

### ✨ New Features
- **Pluggable Session Stores**: Abstract `SessionStore` interface for custom persistence backends
- **MemorySessionStore**: Built-in in-memory store with automatic TTL expiration
- **Session lifecycle hooks**: Automatic load/save with error handling
- **`sessionSecret` parameter**: Configure HMAC secret for production
- **`secureCookies` parameter**: Control HTTPS enforcement (default: `true`)
- **`sessionStore` parameter**: Use Redis, PostgreSQL, or custom backends

### 🔧 Bug Fixes
- Fixed cookie parser discarding empty cookie values (e.g., `logout=`)
- Fixed rate limiter cleanup timer memory leak
- Removed broken `Session.regenerate()` method (session ID is immutable)
- Added proper resource cleanup on server shutdown

### 💥 BREAKING CHANGES
- **Session cookies now require HTTPS in production** (default `secure: true`)
  - Set `secureCookies: false` for local HTTP development
  - Ensure HTTPS is configured for production deployments

### Dependencies
- Added: `crypto: ^3.0.3`

## [1.0.0] - Previous Release

- Initial version
