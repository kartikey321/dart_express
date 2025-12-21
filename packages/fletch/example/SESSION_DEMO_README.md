# Session Security Demo

This example demonstrates production-grade session management with fletch.

## Features Demonstrated

- ✅ HMAC-SHA256 signed session cookies
- ✅ Secure cookie defaults (HTTPS, httpOnly, SameSite: Lax)
- ✅ Environment-based configuration
- ✅ Session data persistence
- ✅ Error handling
- ✅ Development vs Production modes

## Quick Start

### 1. Generate a Session Secret

```bash
# Generate a secure 48-byte random string
openssl rand -base64 48
```

### 2. Set Environment Variables

**Development** (HTTP localhost):
```bash
export SESSION_SECRET="your-generated-secret-at-least-32-characters"
export PORT=3000
# NODE_ENV not set = development mode
```

**Production** (HTTPS required):
```bash
export SESSION_SECRET="your-generated-secret-at-least-32-characters"
export PORT=443
export NODE_ENV=production
```

### 3. Run the Example

```bash
cd example
dart run session_security_demo.dart
```

### 4. Test in Browser

Visit `http://localhost:3000` and try:
- Click "Increment Counter" to see session persistence
- View `/data` to see JSON session data
- Click "Logout" to destroy session
- Refresh page to see new session created

## Security Best Practices Shown

### ✅ Secret Management
```dart
final sessionSecret = Platform.environment['SESSION_SECRET'];
if (sessionSecret == null) {
  print('❌ Error: SESSION_SECRET required');
  exit(1);
}
```

### ✅ Environment Detection
```dart
final isProduction = Platform.environment['NODE_ENV'] == 'production';
final app = Fletch(
  sessionSecret: sessionSecret,
  secureCookies: isProduction, // HTTPS only in production
);
```

### ✅ Session Operations
```dart
// Read
final visits = req.session['visits'] as int? ?? 0;

// Write
req.session['visits'] = visits + 1;

// Destroy
await req.session.destroy();
res.clearCookie(Request.sessionCookieName);
```

## Testing Security

### 1. Test Signed Cookies

Open browser DevTools → Application → Cookies

You should see:
```
Name: sessionId
Value: <uuid>.<signature>  // Note the signature!
HttpOnly: ✓
Secure: ✓ (in production)
SameSite: Lax
```

### 2. Test Tampering Protection

1. Copy your session cookie value
2. Modify the UUID part (before the dot)
3. Refresh the page
4. → You should get a NEW session (old signature invalid)

### 3. Test HTTPS Enforcement (Production)

```bash
NODE_ENV=production dart run session_security_demo.dart
```

Try accessing over HTTP → Cookie won't be set (browser security)

## What's Happening Under the Hood

### Session Creation
1. New visitor → No `sessionId` cookie
2. Server generates UUID: `550e8400-e29b-41d4-a716-446655440000`
3. Server signs it: `550e8400...000.a3f8b2c1d4e5f6...` (HMAC-SHA256)
4. Server sends signed cookie with secure flags

### Session Verification
1. Returning visitor sends cookie: `<uuid>.<signature>`
2. Server splits on `.` → gets UUID and signature
3. Server re-signs UUID with secret
4. Constant-time comparison of signatures
5. ✅ Match: Use session | ❌ Mismatch: New session

### Session Storage
- In-memory (default): Lost on restart, one instance only
- Redis/PostgreSQL: Persistent, works with load balancers

## Production Deployment

### With Docker

```dockerfile
FROM dart:stable

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o server

ENV PORT=8080
ENV NODE_ENV=production

CMD ["./server"]
```

### Environment Variables

```bash
# Required
SESSION_SECRET=<48+ character random string>
NODE_ENV=production

# Optional
PORT=8080
```

### Behind Nginx (Reverse Proxy)

```nginx
server {
    listen 443 ssl;
    server_name yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Troubleshooting

### "Session not persisting"
- Check if cookies are enabled in browser
- In production, ensure HTTPS is configured
- Check browser console for cookie errors

### "SESSION_SECRET error"
- Secret must be at least 32 characters
- Use `openssl rand -base64 48` to generate
- Don't hardcode secrets in code!

### "Cookies not set in production"
- Ensure `secureCookies: true` (default)
- Ensure HTTPS is properly configured
- Check browser requires HTTPS for secure cookies

## Next Steps

- See `redis_session_store_example.dart` for distributed sessions
- See `multi_instance_deployment.dart` for load balancer setup
- Read `SECURITY.md` for comprehensive security guide
