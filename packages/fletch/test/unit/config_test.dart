import 'package:fletch/fletch.dart';
import 'package:test/test.dart';

void main() {
  group('Configuration validation', () {
    test('throws on invalid body size', () {
      expect(
        () => Fletch(maxBodySize: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('warns when file size exceeds body size', () {
      // Should not throw, just warn
      expect(
        () => Fletch(maxBodySize: 1024, maxFileSize: 2048),
        returnsNormally,
      );
    });
  });
}
