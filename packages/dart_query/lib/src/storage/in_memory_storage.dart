import 'query_storage.dart';

class InMemoryQueryStorage implements QueryStorage {
  final Map<String, Map<String, dynamic>> _store = {};

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    _store[key] = Map.from(data);
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    final data = _store[key];
    return data != null ? Map.from(data) : null;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  int get length => _store.length;
}
