import 'package:dart_express/dart_express.dart';
import 'package:test/test.dart';

void main() {
  group('Configuration validation', () {
    test('throws on invalid body size', () {
      expect(
        () => DartExpress(maxBodySize: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('warns when file size exceeds body size', () {
      // Should not throw, just warn
      expect(
        () => DartExpress(maxBodySize: 1024, maxFileSize: 2048),
        returnsNormally,
      );
    });
  });
}
