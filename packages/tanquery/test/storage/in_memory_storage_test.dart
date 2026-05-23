import 'package:test/test.dart';
import 'package:tanquery/src/storage/in_memory_storage.dart';

void main() {
  late InMemoryQueryStorage storage;

  setUp(() => storage = InMemoryQueryStorage());

  group('InMemoryQueryStorage', () {
    test('save and load', () async {
      await storage.save('key1', {'data': 'hello'});
      final loaded = await storage.load('key1');
      expect(loaded, {'data': 'hello'});
    });

    test('load returns null for missing key', () async {
      expect(await storage.load('missing'), isNull);
    });

    test('save overwrites existing', () async {
      await storage.save('key1', {'v': 1});
      await storage.save('key1', {'v': 2});
      expect(await storage.load('key1'), {'v': 2});
    });

    test('remove deletes entry', () async {
      await storage.save('key1', {'data': 'x'});
      await storage.remove('key1');
      expect(await storage.load('key1'), isNull);
    });

    test('clear removes all', () async {
      await storage.save('a', {'v': 1});
      await storage.save('b', {'v': 2});
      await storage.clear();
      expect(storage.length, 0);
    });

    test('returns copy not reference', () async {
      final original = {'data': 'hello'};
      await storage.save('key', original);
      final loaded = await storage.load('key');
      loaded!['data'] = 'modified';
      final reloaded = await storage.load('key');
      expect(reloaded!['data'], 'hello');
    });
  });
}
