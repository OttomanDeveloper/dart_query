import 'package:test/test.dart';
import 'package:dart_query/src/models/infinite_data.dart';

void main() {
  group('InfiniteData', () {
    test('stores pages and pageParams', () {
      final data = InfiniteData<List<String>, int>(
        pages: [
          ['a', 'b'],
          ['c', 'd'],
        ],
        pageParams: [1, 2],
      );
      expect(data.pages.length, 2);
      expect(data.pageParams, [1, 2]);
    });

    test('copyWith replaces pages', () {
      final data = InfiniteData<String, int>(
        pages: ['page1'],
        pageParams: [1],
      );
      final updated = data.copyWith(pages: ['page1', 'page2']);
      expect(updated.pages, ['page1', 'page2']);
      expect(updated.pageParams, [1]); // unchanged
    });

    test('copyWith replaces pageParams', () {
      final data = InfiniteData<String, int>(
        pages: ['page1'],
        pageParams: [1],
      );
      final updated = data.copyWith(pageParams: [1, 2]);
      expect(updated.pages, ['page1']); // unchanged
      expect(updated.pageParams, [1, 2]);
    });

    test('works with cursor-based params', () {
      final data = InfiniteData<List<int>, String>(
        pages: [
          [1, 2, 3]
        ],
        pageParams: ['cursor_abc'],
      );
      expect(data.pageParams.first, 'cursor_abc');
    });
  });
}
