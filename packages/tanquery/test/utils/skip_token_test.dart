import 'package:test/test.dart';
import 'package:tanquery/src/utils/skip_token.dart';

void main() {
  group('skipToken', () {
    test('isSkipToken identifies skipToken', () {
      expect(isSkipToken(skipToken), isTrue);
    });

    test('isSkipToken rejects other values', () {
      expect(isSkipToken(null), isFalse);
      expect(isSkipToken('string'), isFalse);
      expect(isSkipToken(42), isFalse);
      expect(isSkipToken(() => 'fn'), isFalse);
    });

    test('skipToken is a const singleton', () {
      expect(identical(skipToken, skipToken), isTrue);
    });
  });

  group('keepPreviousData', () {
    test('returns previousData unchanged', () {
      expect(keepPreviousData('old', null), 'old');
      expect(keepPreviousData(42, null), 42);
    });

    test('returns null when previousData is null', () {
      expect(keepPreviousData<String>(null, null), isNull);
    });
  });
}
