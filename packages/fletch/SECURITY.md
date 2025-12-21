# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| < 1.1   | :x:                |

---

## Security Features

### Session Management
- **HMAC-SHA256 Signed Cookies**: All session IDs are signed to prevent tampering
- **Secure by Default**: Session cookies use `secure: true`, `httpOnly: true`, `SameSite: Lax`
- **Constant-Time Comparison**: Signature verification resistant to timing attacks
- **Session Stores**: Pluggable backends for distributed deployments

### Configuration
```dart
final app = Fletch(
  sessionSecret: Platform.environment['SESSION_SECRET'], // Required for production
  sessionStore: RedisSessionStore(redis), // For multi-instance deployments
  secureCookies: true, // HTTPS only (default)
);
```

---

## Security Best Practices

### 1. Session Secret Management

**✅ DO:**
```dart
// Load from environment
final secret = Platform.environment['SESSION_SECRET']!;

// Use 32+ character random strings
// Generate with: openssl rand -base64 48
```

**❌ DON'T:**
```dart
// Hardcode secrets
const secret = 'my-secret';  // NEVER do this

// Check into version control
// secrets.dart with hardcoded values
```

### 2. HTTPS in Production

**✅ DO:**
```dart
// Production
final app = Fletch(
  sessionSecret: secret,
  secureCookies: true,  // Requires HTTPS
);
```

**⚠️ Development Only:**
```dart
// Local development over HTTP
final app = Fletch(
  sessionSecret: 'dev-secret-min-32-chars',
  secureCookies: false,  // Allow HTTP (dev only!)
);
```

### 3. Multi-Instance Deployments

Use external session stores:
```dart
// Redis for distributed sessions
final store = RedisSessionStore(redisConnection);

final app = Fletch(
  sessionSecret: secret,
  sessionStore: store,
);
```

### 4. CORS Configuration

**✅ DO: Explicit Origins**
```dart
app.use(app.cors(
  allowedOrigins: ['https://yourdomain.com'],
  allowCredentials: true,
));
```

**❌ DON'T: Wildcard with Credentials**
```dart
// This will throw an error (good!)
app.cors(
  allowedOrigins: ['*'],
  allowCredentials: true,  // ❌ Not allowed
);
```

### 5. Rate Limiting

```dart
app.use(app.rateLimiter(
  maxRequests: 100,
  window: Duration(minutes: 1),
));
```

---

## Threat Model

### Protected Against

| Threat | Mitigation |
|--------|------------|
| Session Tampering | HMAC-SHA256 signatures |
| Session Hijacking (MITM) | `secure: true` (HTTPS only) |
| XSS Session Theft | `httpOnly: true` cookies |
| CSRF Attacks | `SameSite: Lax` default |
| Timing Attacks | Constant-time comparison |
| Cookie Injection | Strict cookie parsing |
| Rate Limit Bypass | Memory-efficient rate limiting |

### Not Currently Protected

| Threat | Recommended Solution |
|--------|---------------------|
| SQL Injection | Use parameterized queries in your app |
| XSS in Responses | Sanitize user input before display |
| CSRF Tokens | Implement CSRF middleware for forms |
| Clickjacking | Set `X-Frame-Options` header |
| CSP | Set `Content-Security-Policy` header |

---

## Reporting a Vulnerability

**Please DO NOT open a public issue** for security vulnerabilities.

Instead, email security details to: **[your-email@example.com]**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will:
1. Acknowledge receipt within 48 hours
2. Investigate and confirm the issue
3. Develop and test a fix
4. Release a security patch
5. Credit you in the CHANGELOG (if desired)

---

## Security Update Policy

- **Critical**: Patched within 24-48 hours
- **High**: Patched within 1 week
- **Medium**: Patched in next minor release
- **Low**: Patched in next major update

---

## Known Limitations

### Session Fixation
Currently, session IDs are immutable. After authentication, consider:
```dart
// Destroy old session
await req.session.destroy();
res.clearCookie(Request.sessionCookieName);
// Client will get new session on next request
```

Future release will add `session.regenerate()` method.

### Concurrent Session Modifications
With external stores (Redis), last-write-wins on concurrent updates.
This is a known limitation of server-side sessions.

### Race Conditions
Session data loaded at start of request, saved at end.
Concurrent requests to same session may overwrite each other.

---

## Additional Resources

- [OWASP Session Management Cheat Sheet](https://cheatsheetsecure.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Dart Security Guidelines](https://dart.dev/guides/security)

---

## Changelog of Security Improvements

### v1.1.0 (Current)
- ✅ Added HMAC-SHA256 session signing
- ✅ Changed secure cookie default to `true`
- ✅ Added `SameSite=Lax` for CSRF protection
- ✅ Implemented pluggable session stores
- ✅ Added error handling for session operations
- ✅ Fixed rate limiter memory leak

### v1.0.0
- Basic session management (unsigned)
- Rate limiting
- CORS support
