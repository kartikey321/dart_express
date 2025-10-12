import 'dart:convert';
import 'dart:io';

/// Simple benchmarking harness that fires HTTP requests against a target
/// endpoint and reports aggregate latency statistics. Designed for quick manual
/// checks rather than exhaustive profiling.
///
/// Usage:
/// ```
/// dart run tool/bench.dart --url http://localhost:8080/health --count 1000 --concurrency 16
/// ```
void main(List<String> args) async {
  final config = _BenchConfig.fromArgs(args);
  final client = HttpClient()..maxConnectionsPerHost = config.concurrency;
  if (config.allowInsecureConnections) {
    client.badCertificateCallback = (_, __, ___) => true;
  }

  final stopwatch = Stopwatch()..start();
  final latencies = <Duration>[];
  int completed = 0;
  int failed = 0;

  final queue = List.generate(config.count, (index) => index);
  final futures = <Future<void>>[];

  void scheduleNext() {
    if (queue.isEmpty) return;
    final idx = queue.removeLast();
    futures.add(_issueRequest(client, config, idx).then((duration) {
      latencies.add(duration);
      completed++;
    }).catchError((_) {
      failed++;
    }).whenComplete(scheduleNext));
  }

  for (var i = 0; i < config.concurrency && i < queue.length; i++) {
    scheduleNext();
  }

  await Future.wait(futures);

  stopwatch.stop();
  client.close();

  latencies.sort();
  final total = latencies.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
  final p50 = latencies.isEmpty
      ? Duration.zero
      : latencies[(latencies.length * 0.5).floor()];
  final p95 = latencies.isEmpty
      ? Duration.zero
      : latencies[(latencies.length * 0.95).floor()];
  final p99 = latencies.isEmpty
      ? Duration.zero
      : latencies[(latencies.length * 0.99).floor()];

  stdout
    ..writeln('Benchmark complete')
    ..writeln('  Target       : ${config.url}')
    ..writeln('  Method       : ${config.method}')
    ..writeln('  Requests     : ${config.count}')
    ..writeln('  Concurrency  : ${config.concurrency}')
    ..writeln('  Duration     : ${stopwatch.elapsed}')
    ..writeln('  Success      : $completed')
    ..writeln('  Failed       : $failed')
    ..writeln('  Avg latency  : ${Duration(microseconds: latencies.isEmpty ? 0 : total ~/ latencies.length)}')
    ..writeln('  P50 latency  : $p50')
    ..writeln('  P95 latency  : $p95')
    ..writeln('  P99 latency  : $p99');
}

Future<Duration> _issueRequest(
  HttpClient client,
  _BenchConfig config,
  int index,
) async {
  final stopwatch = Stopwatch()..start();

  final request = await client.openUrl(config.method, config.url);

  config.headers.forEach(request.headers.set);

  if (config.body != null) {
    request.write(config.body);
  }

  final response = await request.close();
  await response.drain<void>();

  stopwatch.stop();
  return stopwatch.elapsed;
}

class _BenchConfig {
  _BenchConfig({
    required this.url,
    required this.count,
    required this.concurrency,
    required this.method,
    required this.headers,
    this.body,
    required this.allowInsecureConnections,
  });

  factory _BenchConfig.fromArgs(List<String> args) {
    final map = _argMap(args);

    final urlString = map['url'] ?? 'http://localhost:8080/health';
    final uri = Uri.parse(urlString);

    final count = int.tryParse(map['count'] ?? '500') ?? 500;
    final concurrency = int.tryParse(map['concurrency'] ?? '16') ?? 16;
    final method = map['method']?.toUpperCase() ?? 'GET';

    final headers = <String, String>{};
    if (map.containsKey('headers')) {
      final raw = jsonDecode(map['headers']!);
      if (raw is Map<String, dynamic>) {
        raw.forEach((key, value) {
          headers[key] = value.toString();
        });
      }
    }

    final body = map['body'];

    return _BenchConfig(
      url: uri,
      count: count,
      concurrency: concurrency,
      method: method,
      headers: headers,
      body: body,
      allowInsecureConnections: map.containsKey('insecure'),
    );
  }

  final Uri url;
  final int count;
  final int concurrency;
  final String method;
  final Map<String, String> headers;
  final String? body;
  final bool allowInsecureConnections;
}

Map<String, String> _argMap(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    final value = i + 1 < args.length && !args[i + 1].startsWith('--')
        ? args[++i]
        : 'true';
    result[key] = value;
  }
  return result;
}
