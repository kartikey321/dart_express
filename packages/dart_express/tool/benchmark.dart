import 'dart:async';
import 'dart:io';

import 'package:dart_express/dart_express.dart';

Future<void> main(List<String> args) async {
  final app = DartExpress();

  app.get('/bench', (req, res) {
    res.json({
      'status': 'ok',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'requestId': req.requestId,
    });
  });

  app.enableHealthCheck();

  await app.listen(8080);

  stdout.writeln('''
Benchmark endpoints:
  - GET /bench   (JSON)
  - GET /health  (health check)

Run load with:
  wrk -t4 -c100 -d30s http://localhost:8080/bench
or:
  ab -n 10000 -c 100 http://localhost:8080/bench
''');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nShutting down gracefully...');
    await app.close();
    exit(0);
  });

  // Keep the process alive until SIGINT.
  await Completer<void>().future;
}
