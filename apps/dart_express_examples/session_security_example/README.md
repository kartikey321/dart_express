# Session Security Example

Production-grade session security demonstration with dart_express.

## Features

✅ HMAC-SHA256 signed session cookies  
✅ Secure defaults (HTTPS, httpOnly, SameSite: Lax)  
✅ Environment-based configuration  
✅ Interactive web UI for testing  
✅ Session tampering detection  
✅ Error handling  

## Quick Start

### 1. Generate Secret

```bash
openssl rand -base64 48
```

### 2. Set Environment

```bash
export SESSION_SECRET="your-48-char-secret-here"
export PORT=3000
```

### 3. Install Dependencies

```bash
dart pub get
```

### 4. Run

```bash
dart run bin/server.dart
```

### 5. Open Browser

Visit `http://localhost:3000`

## Try It Out

- **Increment Counter**: See sessions persist across requests
- **View JSON**: Inspect session data structure
- **Set Data**: Store custom values in session
- **Logout**: Destroy session and start fresh

## Security Testing

### Test 1: Cookie Tampering

1. Open DevTools → Application → Cookies
2. Find `sessionId` cookie value like: `uuid.signature`
3. Modify the UUID part (before the dot)
4. Refresh page → New session created (tampering detected!)

### Test 2: Signature Verification

```bash
# Session cookie format: <uuid>.<hmac-signature>
# Example: 550e8400-e29b-41d4-a716-446655440000.a3f8b2c1...
```

The server:
1. Splits cookie on `.`
2. Re-signs UUID with your secret
3. Compares signatures (constant-time)
4. ✅ Match = valid | ❌ Mismatch = new session

## Production Deployment

```bash
export SESSION_SECRET="<secure-48-char-random-string>"
export NODE_ENV=production
export PORT=443

dart compile exe bin/server.dart -o server
./server
```

**Requirements**:
- HTTPS configured (reverse proxy or native TLS)
- SESSION_SECRET from secure vault
- Production environment variables set

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SESSION_SECRET` | Yes | - | 32+ char secret for HMAC |
| `NODE_ENV` | No | development | Set to `production` for HTTPS |
| `PORT` | No | 3000 | Server port |

## Code Highlights

### Secure Configuration

```dart
final app = DartExpress(
  sessionSecret: Platform.environment['SESSION_SECRET']!,
  secureCookies: isProduction, // HTTPS in prod
  requestTimeout: Duration(seconds: 30),
);
```

### Session Operations

```dart
// Read
final visits = req.session['visits'] as int? ?? 0;

// Write
req.session['visits'] = visits + 1;

// Destroy
await req.session.destroy();
res.clearCookie(Request.sessionCookieName);
```

## Next Steps

- See `mongo_example` for MongoDB session store
- See `redis_example` for Redis session store (coming soon)
- Read `SECURITY.md` for comprehensive security guide

## Troubleshooting

**Sessions not persisting?**
- Check browser allows cookies
- In production, ensure HTTPS is configured
- Verify SESSION_SECRET is set

**"SESSION_SECRET required" error?**
- Secret must be at least 32 characters
- Use `openssl rand -base64 48`
- Never hardcode secrets!

**Cookies not set in production?**
- Ensure `secureCookies: true` (default)
- Verify HTTPS is properly configured
- Check browser security settings
