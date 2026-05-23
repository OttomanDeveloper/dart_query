abstract class QueryStorage {
  Future<void> save(String key, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> load(String key);
  Future<void> remove(String key);
  Future<void> clear();
}
