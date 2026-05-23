import 'package:test/test.dart';
import 'package:tanquery/src/hydration/hydration.dart';
import 'package:tanquery/src/query_client.dart';
import 'package:tanquery/src/models/query_key.dart';
import 'package:tanquery/src/models/types.dart';
import 'package:tanquery/src/core/notify_manager.dart';
import 'package:tanquery/src/core/focus_manager.dart';
import 'package:tanquery/src/core/online_manager.dart';

void main() {
  late QueryClient client;

  setUp(() {
    final notify = NotifyManager()..setScheduler((cb) => cb());
    client = QueryClient(
      notifyManager: notify,
      focusManager: FocusManager()..setFocused(true),
      onlineManager: OnlineManager()..setOnline(true),
    );
  });

  group('dehydrate', () {
    test('dehydrates successful queries', () {
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => '',
        initialData: 'hello',
      );
      cache.build<int>(
        queryKey: QueryKey(['count']),
        queryFn: () async => 0,
        initialData: 42,
      );

      final state = dehydrate(client);
      expect(state.queries.length, 2);
      expect(state.queries[0].queryHash, '["todos"]');
      expect(state.queries[0].state['data'], 'hello');
      expect(state.queries[1].state['data'], 42);
    });

    test('skips pending queries by default', () {
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['pending']),
        queryFn: () async => '',
      );
      final state = dehydrate(client);
      expect(state.queries.length, 0);
    });

    test('custom shouldDehydrateQuery filter', () {
      final cache = client.getQueryCache();
      cache.build<String>(queryKey: QueryKey(['a']), queryFn: () async => '', initialData: 'a');
      cache.build<String>(queryKey: QueryKey(['b']), queryFn: () async => '', initialData: 'b');

      final state = dehydrate(
        client,
        DehydrateOptions(
          shouldDehydrateQuery: (q) => q.queryHash.contains('a'),
        ),
      );
      expect(state.queries.length, 1);
      expect(state.queries[0].queryHash, contains('a'));
    });

    test('records dehydratedAt timestamp', () {
      final cache = client.getQueryCache();
      cache.build<String>(queryKey: QueryKey(['ts']), queryFn: () async => '', initialData: 'data');

      final state = dehydrate(client);
      expect(state.queries[0].dehydratedAt, isNotNull);
    });
  });

  group('hydrate', () {
    test('restores queries into cache', () {
      final state = DehydratedState(queries: [
        DehydratedQuery(
          queryHash: '["restored"]',
          queryKey: ['restored'],
          state: {
            'data': 'restored_data',
            'status': 'success',
            'dataUpdatedAt': DateTime.now().millisecondsSinceEpoch,
            'isInvalidated': false,
          },
        ),
      ]);

      hydrate(client, state);
      final data = client.getQueryData<String>(QueryKey(['restored']));
      expect(data, 'restored_data');
    });

    test('does not overwrite newer existing data', () {
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['existing']),
        queryFn: () async => '',
        initialData: 'newer',
      );

      final state = DehydratedState(queries: [
        DehydratedQuery(
          queryHash: '["existing"]',
          queryKey: ['existing'],
          state: {
            'data': 'older',
            'status': 'success',
            'dataUpdatedAt': DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
            'isInvalidated': false,
          },
        ),
      ]);

      hydrate(client, state);
      expect(client.getQueryData<String>(QueryKey(['existing'])), 'newer');
    });

    test('overwrites older existing data', () {
      final cache = client.getQueryCache();
      cache.build<String>(
        queryKey: QueryKey(['old']),
        queryFn: () async => '',
        initialData: 'old_data',
        initialDataUpdatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final state = DehydratedState(queries: [
        DehydratedQuery(
          queryHash: '["old"]',
          queryKey: ['old'],
          state: {
            'data': 'fresh_data',
            'status': 'success',
            'dataUpdatedAt': DateTime.now().millisecondsSinceEpoch,
            'isInvalidated': false,
          },
        ),
      ]);

      hydrate(client, state);
      expect(client.getQueryData<String>(QueryKey(['old'])), 'fresh_data');
    });

    test('never sets fetchStatus to fetching', () {
      final state = DehydratedState(queries: [
        DehydratedQuery(
          queryHash: '["idle"]',
          queryKey: ['idle'],
          state: {
            'data': 'data',
            'status': 'success',
            'dataUpdatedAt': DateTime.now().millisecondsSinceEpoch,
            'isInvalidated': false,
          },
        ),
      ]);

      hydrate(client, state);
      final queryState = client.getQueryState(QueryKey(['idle']));
      expect(queryState!.fetchStatus, FetchStatus.idle);
    });
  });

  group('DehydratedState serialization', () {
    test('round-trip toJson/fromJson', () {
      final original = DehydratedState(queries: [
        DehydratedQuery(
          queryHash: '["test"]',
          queryKey: ['test'],
          state: {'data': 'hello', 'status': 'success', 'dataUpdatedAt': 1000, 'isInvalidated': false},
          dehydratedAt: DateTime.fromMillisecondsSinceEpoch(2000),
          queryType: 'infinite',
        ),
      ]);

      final json = original.toJson();
      final restored = DehydratedState.fromJson(json);

      expect(restored.queries.length, 1);
      expect(restored.queries[0].queryHash, '["test"]');
      expect(restored.queries[0].state['data'], 'hello');
      expect(restored.queries[0].dehydratedAt?.millisecondsSinceEpoch, 2000);
      expect(restored.queries[0].queryType, 'infinite');
    });
  });
}
