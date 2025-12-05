import 'dart:async';

import 'package:test/test.dart';

import '../helpers/test_server_harness.dart';

void main() {
  group('Concurrency', () {
    late TestServerHarness harness;

    setUp(() => harness = TestServerHarness());
    tearDown(() => harness.dispose());

    test('handles many concurrent requests without head-of-line blocking',
        () async {
      final active = <int>[];
      var inFlight = 0;

      harness.app.get('/work', (req, res) async {
        inFlight++;
        active.add(inFlight);
        await Future.delayed(const Duration(milliseconds: 40));
        inFlight--;
        res.text('ok');
      });

      final requests =
          List.generate(40, (_) => harness.get('/work')); // 40 concurrent

      final stopwatch = Stopwatch()..start();
      final responses = await Future.wait(requests);
      stopwatch.stop();

      for (final response in responses) {
        expect(response.statusCode, 200);
      }

      expect(active.any((c) => c > 1), isTrue);
      // Sequential would be ~1600ms; allow generous headroom.
      expect(stopwatch.elapsedMilliseconds, lessThan(1200));
    });
  });
}
