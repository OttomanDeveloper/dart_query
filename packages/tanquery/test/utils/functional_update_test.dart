import 'package:test/test.dart';
import 'package:tanquery/src/utils/functional_update.dart';

void main() {
  group('functionalUpdate', () {
    test('returns value directly when not a function', () {
      expect(functionalUpdate<int>(42, 0), 42);
    });

    test('calls function with input when updater is a function', () {
      expect(functionalUpdate<int>((int old) => old + 10, 5), 15);
    });

    test('works with strings', () {
      expect(functionalUpdate<String>('new', 'old'), 'new');
      expect(functionalUpdate<String>((String old) => '${old}_updated', 'data'), 'data_updated');
    });
  });

  group('shouldThrowError', () {
    test('returns true when throwOnError is true', () {
      expect(shouldThrowError(true, [Exception('e')]), isTrue);
    });

    test('returns false when throwOnError is false', () {
      expect(shouldThrowError(false, [Exception('e')]), isFalse);
    });

    test('returns false when throwOnError is null', () {
      expect(shouldThrowError(null, [Exception('e')]), isFalse);
    });

    test('calls function when throwOnError is a function', () {
      bool checker(Object error) => error.toString().contains('critical');
      expect(shouldThrowError(checker, [Exception('critical error')]), isTrue);
      expect(shouldThrowError(checker, [Exception('minor')]), isFalse);
    });
  });
}
