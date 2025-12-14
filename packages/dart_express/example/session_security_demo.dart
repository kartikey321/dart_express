import 'dart:io';
import 'package:dart_express/dart_express.dart';

/// Production-Ready Session Security Example
///
/// This example demonstrates:
/// - HMAC-SHA256 signed session cookies
/// - Secure cookie defaults (HTTPS, httpOnly, SameSite)
/// - Environment-based configuration
/// - Session data persistence
/// - Error handling
Future<void> main() async {
  // 1. Load session secret from environment (REQUIRED for production)
  final sessionSecret = Platform.environment['SESSION_SECRET'];

  if (sessionSecret == null) {
    print('❌ Error: SESSION_SECRET environment variable is required');
    print('');
    print('Generate a secure secret:');
    print('  openssl rand -base64 48');
    print('');
    print('Then set it:');
    print('  export SESSION_SECRET="your-generated-secret"');
    exit(1);
  }

  // Validate secret length
  if (sessionSecret.length < 32) {
    print('❌ Error: SESSION_SECRET must be at least 32 characters long');
    exit(1);
  }

  // 2. Determine environment (production vs development)
  final isProduction = Platform.environment['NODE_ENV'] == 'production';

  print(
      '🚀 Starting dart_express in ${isProduction ? "PRODUCTION" : "DEVELOPMENT"} mode');
  print('');

  // 3. Create app with production-ready security settings
  final app = DartExpress(
    sessionSecret: sessionSecret,
    secureCookies: isProduction, // HTTPS only in production
    requestTimeout: const Duration(seconds: 30),
  );

  // 4. Add middleware
  app.use((req, res, next) async {
    print('[${DateTime.now()}] ${req.method} ${req.uri.path}');
    await next();
  });

  // 5. Demo routes showing session usage

  // Home: Show current session
  app.get('/', (req, res) {
    final visits = (req.session['visits'] as int?) ?? 0;

    res.html('''
      <!DOCTYPE html>
      <html>
      <head>
        <title>Session Security Demo</title>
        <style>
          body { 
            font-family: system-ui; 
            max-width: 800px; 
            margin: 50px auto; 
            padding: 20px;
          }
          .info { background: #e3f2fd; padding: 15px; border-radius: 5px; margin: 10px 0; }
          .success { background: #c8e6c9; padding: 15px; border-radius: 5px; margin: 10px 0; }
          code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
        </style>
      </head>
      <body>
        <h1>🔒 Secure Session Demo</h1>
        
        <div class="success">
          <strong>Session ID:</strong> <code>${req.session.id}</code><br>
          <strong>Visits:</strong> $visits
        </div>

        <div class="info">
          <h3>Security Features Active:</h3>
          <ul>
            <li>✅ HMAC-SHA256 signed cookies</li>
            <li>✅ Secure: ${isProduction ? 'true (HTTPS only)' : 'false (dev mode)'}</li>
            <li>✅ HttpOnly: true (no JavaScript access)</li>
            <li>✅ SameSite: Lax (CSRF protection)</li>
          </ul>
        </div>

        <p>
          <a href="/increment">Increment Counter</a> | 
          <a href="/data">View Session Data</a> | 
          <a href="/logout">Logout (Clear Session)</a>
        </p>
      </body>
      </html>
    ''');
  });

  // Increment session counter
  app.get('/increment', (req, res) {
    final visits = (req.session['visits'] as int?) ?? 0;
    req.session['visits'] = visits + 1;
    req.session['lastVisit'] = DateTime.now().toIso8601String();

    res.redirect('/');
  });

  // Show all session data
  app.get('/data', (req, res) {
    res.json({
      'sessionId': req.session.id,
      'isNewSession': req.isNewSession,
      'data': req.session.data,
    });
  });

  // Clear session (logout)
  app.get('/logout', (req, res) async {
    await req.session.destroy();
    res.clearCookie(Request.sessionCookieName);
    res.text('Session cleared! Visit / to start a new session.');
  });

  // Error handler
  app.setErrorHandler((error, req, res) async {
    print('Error: $error');
    res.json({
      'error': isProduction ? 'Internal Server Error' : error.toString(),
    }, statusCode: 500);
  });

  // 6. Start server
  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  await app.listen(port);

  print('');
  print('✅ Server running on http${isProduction ? 's' : ''}://localhost:$port');
  print('');
  print('Try these endpoints:');
  print('  GET  /          - Home page with session info');
  print('  GET  /increment - Increment visit counter');
  print('  GET  /data      - View session data (JSON)');
  print('  GET  /logout    - Clear session');
  print('');

  if (!isProduction) {
    print('⚠️  Running in DEVELOPMENT mode (HTTP allowed)');
    print('   For production, set NODE_ENV=production and use HTTPS');
  }
}
