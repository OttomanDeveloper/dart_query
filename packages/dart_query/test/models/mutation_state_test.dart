import 'package:test/test.dart';
import 'package:dart_query/src/models/mutation_state.dart';
import 'package:dart_query/src/models/types.dart';

void main() {
  group('MutationState', () {
    test('default state is idle', () {
      final state = MutationState<String>();
      expect(state.status, MutationStatus.idle);
      expect(state.isIdle, isTrue);
      expect(state.isPending, isFalse);
      expect(state.isError, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.data, isNull);
      expect(state.error, isNull);
    });

    test('pending state', () {
      final state = MutationState<String>(status: MutationStatus.pending);
      expect(state.isPending, isTrue);
      expect(state.isIdle, isFalse);
    });

    test('success state with data', () {
      final state = MutationState<String>(
        status: MutationStatus.success,
        data: 'result',
      );
      expect(state.isSuccess, isTrue);
      expect(state.data, 'result');
    });

    test('error state with error', () {
      final state = MutationState<String>(
        status: MutationStatus.error,
        error: Exception('fail'),
      );
      expect(state.isError, isTrue);
      expect(state.error, isA<Exception>());
    });

    test('copyWith preserves unchanged fields', () {
      final state = MutationState<String>(
        status: MutationStatus.success,
        data: 'hello',
        failureCount: 2,
      );
      final updated = state.copyWith(status: MutationStatus.error);
      expect(updated.data, 'hello');
      expect(updated.failureCount, 2);
      expect(updated.status, MutationStatus.error);
    });

    test('copyWith can set nullable fields to null', () {
      final state = MutationState<String>(data: 'hello', error: 'err');
      final cleared = state.copyWith(data: () => null, error: () => null);
      expect(cleared.data, isNull);
      expect(cleared.error, isNull);
    });
  });
}
