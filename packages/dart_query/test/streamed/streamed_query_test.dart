import 'dart:async';
import 'package:test/test.dart';
import 'package:dart_query/src/streamed/streamed_query.dart';

void main() {
  group('streamedQuery', () {
    test('accumulates stream chunks with reducer', () async {
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.fromIterable([1, 2, 3]),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
      );

      final result = await queryFn();
      expect(result, [1, 2, 3]);
    });

    test('works with string concatenation', () async {
      final queryFn = streamedQuery<String, String>(
        streamFn: () => Stream.fromIterable(['hello', ' ', 'world']),
        reducer: (acc, chunk) => acc + chunk,
        initialValue: '',
      );

      final result = await queryFn();
      expect(result, 'hello world');
    });

    test('calls onData for each chunk', () async {
      final updates = <List<int>>[];
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.fromIterable([1, 2, 3]),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
        onData: (data) => updates.add(List.from(data)),
      );

      await queryFn();
      expect(updates, [
        [1],
        [1, 2],
        [1, 2, 3],
      ]);
    });

    test('returns initialValue for empty stream', () async {
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => const Stream.empty(),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [0],
      );

      final result = await queryFn();
      expect(result, [0]);
    });

    test('works with async stream controller', () async {
      final controller = StreamController<String>();

      final queryFn = streamedQuery<String, List<String>>(
        streamFn: () => controller.stream,
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
      );

      final future = queryFn();

      controller.add('a');
      controller.add('b');
      controller.add('c');
      await controller.close();

      final result = await future;
      expect(result, ['a', 'b', 'c']);
    });

    test('propagates stream errors', () async {
      final queryFn = streamedQuery<int, List<int>>(
        streamFn: () => Stream.error(Exception('stream error')),
        reducer: (acc, chunk) => [...acc, chunk],
        initialValue: [],
      );

      await expectLater(queryFn(), throwsException);
    });
  });
}
