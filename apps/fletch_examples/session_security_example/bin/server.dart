import 'dart:io';
import 'package:fletch/fletch.dart';

/// Production-Ready Session Security Example
///
/// Demonstrates:
/// - HMAC-SHA256 signed sessions
/// - Secure cookie defaults
/// - Environment configuration
/// - Session persistence
/// - Error handling
Future<void> main() async {
  // Load configuration from environment
  final sessionSecret = Platform.environment['SESSION_SECRET'];

  if (sessionSecret == null || sessionSecret.length < 32) {
    print('❌ Error: SESSION_SECRET must be at least 32 characters');
    print('Generate one: openssl rand -base64 48');
    exit(1);
  }

  final isProduction = Platform.environment['NODE_ENV'] == 'production';

  print('🚀 Starting in ${isProduction ? "PRODUCTION" : "DEVELOPMENT"} mode\n');

  // Create app with security
  final app = Fletch(
    sessionSecret: sessionSecret,
    secureCookies: isProduction,
    requestTimeout: const Duration(seconds: 30),
  );

  // Logging middleware
  app.use((req, res, next) async {
    print('[${DateTime.now()}] ${req.method} ${req.uri.path}');
    await next();
  });

  // Home page
  app.get('/', (req, res) {
    final visits = (req.session['visits'] as int?) ?? 0;

    res.html('''
      <!DOCTYPE html>
      <html>
      <head>
        <title>Session Security Demo</title>
        <style>
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            max-width: 900px; 
            margin: 50px auto; 
            padding: 20px;
            background: #f5f5f5;
          }
          .card { 
            background: white; 
            padding: 25px; 
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin: 15px 0;
          }
          .success { background: #c8e6c9; }
          .info { background: #e3f2fd; }
          code { 
            background: #f5f5f5; 
            padding: 3px 8px; 
            border-radius: 4px;
            font-family: 'Monaco', monospace;
            font-size: 0.9em;
          }
          h1 { color: #1976d2; }
          a { 
            color: #1976d2; 
            text-decoration: none;
            margin-right: 15px;
          }
          a:hover { text-decoration: underline; }
          ul { line-height: 1.8; }
        </style>
      </head>
      <body>
        <h1>🔒 Secure Session Demo</h1>
        
        <div class="card success">
          <h3>Your Session</h3>
          <strong>Session ID:</strong> <code>${req.session.id}</code><br>
          <strong>Visit Count:</strong> <strong style="font-size: 1.5em">${visits}</strong>
        </div>

        <div class="card info">
          <h3>Active Security Features</h3>
          <ul>
            <li>✅ <strong>HMAC-SHA256</strong> cryptographic signatures</li>
            <li>✅ <strong>Secure:</strong> ${isProduction ? 'true (HTTPS only)' : 'false (dev mode)'}</li>
            <li>✅ <strong>HttpOnly:</strong> true (XSS protection)</li>
            <li>✅ <strong>SameSite:</strong> Lax (CSRF protection)</li>
            <li>✅ <strong>Constant-time</strong> signature verification</li>
          </ul>
        </div>

        <div class="card">
          <h3>Try It Out</h3>
          <p>
            <a href="/increment">📈 Increment Counter</a>
            <a href="/data">📊 View Session JSON</a>
            <a href="/set-data">💾 Set Custom Data</a>
            <a href="/logout">🚪 Logout</a>
          </p>
        </div>

        <div class="card">
          <h3>Security Test</h3>
          <p><strong>Try tampering with your session cookie:</strong></p>
          <ol>
            <li>Open DevTools → Application → Cookies</li>
            <li>Find cookie named <code>sessionId</code></li>
            <li>Modify the value (break the signature)</li>
            <li>Refresh this page</li>
            <li>→ You'll get a NEW session (tampering detected!)</li>
          </ol>
        </div>
      </body>
      </html>
    ''');
  });

  // Increment counter
  app.get('/increment', (req, res) {
    final visits = (req.session['visits'] as int?) ?? 0;
    req.session['visits'] = visits + 1;
    req.session['lastVisit'] = DateTime.now().toIso8601String();
    res.redirect('/');
  });

  // Set custom data
  app.get('/set-data', (req, res) {
    req.session['username'] = 'Alice';
    req.session['role'] = 'admin';
    req.session['loginTime'] = DateTime.now().toIso8601String();
    res.redirect('/data');
  });

  // View session data as JSON
  app.get('/data', (req, res) {
    res.json({
      'sessionId': req.session.id,
      'isNewSession': req.isNewSession,
      'data': req.session.data,
      'cookieHeader': req.headers.value('cookie'),
    });
  });

  // Logout - destroy session
  app.get('/logout', (req, res) async {
    await req.session.destroy();
    res.clearCookie(Request.sessionCookieName);

    res.html('''
      <!DOCTYPE html>
      <html>
      <head>
        <title>Logged Out</title>
        <style>
          body { font-family: sans-serif; text-align: center; padding: 50px; }
          .message { 
            background: #fff3cd; 
            padding: 20px; 
            border-radius: 8px; 
            display: inline-block;
          }
        </style>
      </head>
      <body>
        <div class="message">
          <h2>✅ Session Destroyed</h2>
          <p>Your session has been cleared.</p>
          <p><a href="/">← Back to Home (new session)</a></p>
        </div>
      </body>
      </html>
    ''');
  });

  // Error handler
  app.setErrorHandler((error, req, res) async {
    print('❌ Error: $error');
    res.json({
      'error': isProduction ? 'Internal Server Error' : error.toString(),
      'sessionId': req.session.id,
    }, statusCode: 500);
  });

  // Health check
  app.enableHealthCheck();

  // Start server
  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  await app.listen(port);

  print(
      '✅ Server running on http${isProduction ? 's' : ''}://localhost:$port\n');
  print('Endpoints:');
  print('  GET  /          - Interactive demo');
  print('  GET  /increment - Increment counter');
  print('  GET  /data      - View session JSON');
  print('  GET  /set-data  - Set custom data');
  print('  GET  /logout    - Destroy session');
  print('  GET  /health    - Health check\n');

  if (!isProduction) {
    print('⚠️  DEV MODE: HTTP allowed');
    print('   Set NODE_ENV=production for HTTPS enforcement\n');
  }
}
