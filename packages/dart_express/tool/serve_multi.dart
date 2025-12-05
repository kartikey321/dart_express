import 'dart:io';
import 'dart:isolate';

import 'package:dart_express/dart_express.dart';

Future<void> main(List<String> args) async {
  final workers =
      args.isNotEmpty ? int.parse(args.first) : Platform.numberOfProcessors;
  final port = args.length > 1 ? int.parse(args[1]) : 8080;

  // Spawn worker isolates (leave one in the main isolate)
  for (var i = 0; i < workers - 1; i++) {
    await Isolate.spawn(_startWorker, [port]);
  }
  await _startWorker([port]); // main worker
}

Future<void> _startWorker(List<dynamic> params) async {
  final port = params[0] as int;
  final app = DartExpress();

  app.get('/bench', (req, res) {
    res.json({'status': 'ok', 'requestId': req.requestId});
  });
  app.enableHealthCheck();

  await app.listen(
    port,
    address: InternetAddress.loopbackIPv4,
    shared: true,
  );
}
