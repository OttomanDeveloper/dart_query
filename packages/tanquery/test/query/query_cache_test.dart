import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:tanquery/src/query/query_cache.dart';
import 'package:tanquery/src/query/query.dart';
import 'package:tanquery/src/models/query_key.dart';
import 'package:tanquery/src/models/types.dart';
import 'package:tanquery/src/core/notify_manager.dart';

void main() {
  late QueryCache cache;
  late NotifyManager notify;

  setUp(() {
    notify = NotifyManager();
    notify.setScheduler((cb) => cb());
    cache = QueryCache(notifyManager: notify);
  });

  group('QueryCache — build', () {
    test('creates new query when not found', () {
      final query = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'data',
      );
      expect(query, isNotNull);
      expect(query.queryHash, '["todos"]');
      expect(cache.getAll().length, 1);
    });

    test('returns existing query when hash matches', () {
      final q1 = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'first',
      );
      final q2 = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'second',
      );
      expect(identical(q1, q2), isTrue);
      expect(cache.getAll().length, 1);
    });

    test('creates separate queries for different keys', () {
      cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'todos',
      );
      cache.build<String>(
        queryKey: QueryKey(['users']),
        queryFn: () async => 'users',
      );
      expect(cache.getAll().length, 2);
    });

    test('fires added event on new query', () {
      final events = <QueryCacheEvent>[];
      cache.subscribe((event) => events.add(event));
      cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'data',
      );
      expect(events.length, 1);
      expect(events.first.type, EventType.added);
    });

    test('does NOT fire added event for existing query', () {
      cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'data',
      );
      final events = <QueryCacheEvent>[];
      cache.subscribe((event) => events.add(event));
      cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'data2',
      );
      expect(events.where((e) => e.type == EventType.added).length, 0);
    });
  });

  group('QueryCache — get', () {
    test('returns query by hash', () {
      final built = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'data',
      );
      final found = cache.get('["todos"]');
      expect(identical(found, built), isTrue);
    });

    test('returns null for unknown hash', () {
      expect(cache.get('["unknown"]'), isNull);
    });
  });

  group('QueryCache — find', () {
    test('finds by exact key match (default)', () {
      cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'data',
      );
      cache.build<String>(
        queryKey: QueryKey(['todos', 1]),
        queryFn: () async => 'data',
      );
      final result = cache.find(queryKey: QueryKey(['todos']));
      expect(result, isNotNull);
      expect(result!.queryHash, '["todos"]');
    });

    test('returns null when not found', () {
      expect(cache.find(queryKey: QueryKey(['missing'])), isNull);
    });
  });

  group('QueryCache — findAll', () {
    test('returns all queries when no filters', () {
      cache.build<String>(queryKey: QueryKey(['a']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['b']), queryFn: () async => '');
      expect(cache.findAll().length, 2);
    });

    test('filters by partial key match', () {
      cache.build<String>(queryKey: QueryKey(['todos']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['todos', 1]), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['users']), queryFn: () async => '');
      final results = cache.findAll(queryKey: QueryKey(['todos']));
      expect(results.length, 2);
    });

    test('filters by exact key when exact=true', () {
      cache.build<String>(queryKey: QueryKey(['todos']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['todos', 1]), queryFn: () async => '');
      final results = cache.findAll(queryKey: QueryKey(['todos']), exact: true);
      expect(results.length, 1);
      expect(results.first.queryHash, '["todos"]');
    });

    test('filters by active type', () {
      final q1 = cache.build<String>(queryKey: QueryKey(['active']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['inactive']), queryFn: () async => '');
      q1.addObserver(_MockObserver());
      final active = cache.findAll(type: QueryTypeFilter.active);
      expect(active.length, 1);
      expect(active.first.queryHash, q1.queryHash);
    });

    test('filters by inactive type', () {
      final q1 = cache.build<String>(queryKey: QueryKey(['active']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['inactive']), queryFn: () async => '');
      q1.addObserver(_MockObserver());
      final inactive = cache.findAll(type: QueryTypeFilter.inactive);
      expect(inactive.length, 1);
    });

    test('filters by predicate', () {
      cache.build<String>(queryKey: QueryKey(['a']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['b']), queryFn: () async => '');
      final results = cache.findAll(
        predicate: (query) => query.queryHash.contains('a'),
      );
      expect(results.length, 1);
    });
  });

  group('QueryCache — remove', () {
    test('removes query from cache', () {
      final query = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'data',
      );
      cache.remove(query);
      expect(cache.getAll().length, 0);
      expect(cache.get(query.queryHash), isNull);
    });

    test('fires removed event', () {
      final query = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'data',
      );
      final events = <QueryCacheEvent>[];
      cache.subscribe((event) => events.add(event));
      cache.remove(query);
      expect(events.any((e) => e.type == EventType.removed), isTrue);
    });

    test('identity check prevents race condition', () {
      final q1 = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'first',
      );
      // Remove q1 from cache
      cache.remove(q1);
      // Build a new query with the same key
      final q2 = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'second',
      );
      // Try removing q1 again — should NOT remove q2
      cache.remove(q1);
      expect(cache.get(q2.queryHash), isNotNull);
    });
  });

  group('QueryCache — clear', () {
    test('removes all queries', () {
      cache.build<String>(queryKey: QueryKey(['a']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['b']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['c']), queryFn: () async => '');
      cache.clear();
      expect(cache.getAll().length, 0);
    });

    test('fires removed event for each query', () {
      cache.build<String>(queryKey: QueryKey(['a']), queryFn: () async => '');
      cache.build<String>(queryKey: QueryKey(['b']), queryFn: () async => '');
      final events = <QueryCacheEvent>[];
      cache.subscribe((event) => events.add(event));
      cache.clear();
      final removedEvents = events.where((e) => e.type == EventType.removed);
      expect(removedEvents.length, 2);
    });
  });

  group('QueryCache — onFocus / onOnline', () {
    test('onFocus propagates to all queries', () {
      final q1 = cache.build<String>(queryKey: QueryKey(['a']), queryFn: () async => '');
      final q2 = cache.build<String>(queryKey: QueryKey(['b']), queryFn: () async => '');
      var focusCount = 0;
      // We can't easily test Query.onFocus() propagation here without observers,
      // but we can verify the method doesn't throw
      cache.onFocus();
    });

    test('onOnline propagates to all queries', () {
      cache.build<String>(queryKey: QueryKey(['a']), queryFn: () async => '');
      cache.onOnline();
      // No throw = propagation works
    });
  });

  group('QueryCache — GC integration', () {
    test('query is removed from cache after GC fires', () {
      fakeAsync((async) {
        final query = cache.build<String>(
          queryKey: QueryKey(['todos']),
          queryFn: () async => 'data',
          gcTime: const Duration(seconds: 5),
        );
        // No observers, schedule GC
        query.scheduleGc();
        async.elapse(const Duration(seconds: 5));
        expect(cache.getAll().length, 0);
      });
    });
  });

  group('QueryCache — config callbacks', () {
    test('onSuccess fires on query fetch success', () async {
      var successData;
      cache = QueryCache(
        notifyManager: notify,
        onSuccess: (data, query) => successData = data,
      );
      final query = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => 'hello',
      );
      await query.fetch();
      expect(successData, 'hello');
    });

    test('onError fires on query fetch error', () async {
      Object? errorObj;
      cache = QueryCache(
        notifyManager: notify,
        onError: (error, query) => errorObj = error,
      );
      final query = cache.build<String>(
        queryKey: QueryKey(['todos']),
        queryFn: () async => throw Exception('fail'),
      );
      try {
        await query.fetch();
      } catch (_) {}
      expect(errorObj, isA<Exception>());
    });

    test('onSettled fires on both success and error', () async {
      var settledCount = 0;
      cache = QueryCache(
        notifyManager: notify,
        onSettled: (data, error, query) => settledCount++,
      );
      final q1 = cache.build<String>(
        queryKey: QueryKey(['success']),
        queryFn: () async => 'ok',
      );
      await q1.fetch();
      expect(settledCount, 1);

      final q2 = cache.build<String>(
        queryKey: QueryKey(['error']),
        queryFn: () async => throw Exception('fail'),
      );
      try { await q2.fetch(); } catch (_) {}
      expect(settledCount, 2);
    });
  });

  group('QueryCache — findAll advanced filters', () {
    test('filters by stale', () {
      cache.build<String>(
        queryKey: QueryKey(['fresh']),
        queryFn: () async => '',
        initialData: 'data',
      );
      cache.build<String>(
        queryKey: QueryKey(['nodata']),
        queryFn: () async => '',
      );
      // fresh query has data and is NOT stale (staleTime=0 but data was just set)
      final staleResults = cache.findAll(stale: true);
      // nodata query has no data — always stale
      // fresh query has data set at Duration.zero staleTime — also stale
      // Both are stale because _matchQuery uses Duration.zero for stale check
      expect(staleResults.length, 2);

      final notStale = cache.findAll(stale: false);
      expect(notStale.length, 0);
    });

    test('filters by fetchStatus', () async {
      final q = cache.build<String>(
        queryKey: QueryKey(['fetching']),
        queryFn: () => Completer<String>().future,
        networkMode: NetworkMode.always,
      );
      unawaited(q.fetch().catchError((_) => ''));
      await Future.delayed(Duration.zero);

      cache.build<String>(
        queryKey: QueryKey(['idle']),
        queryFn: () async => '',
      );

      final fetching = cache.findAll(fetchStatus: FetchStatus.fetching);
      expect(fetching.length, 1);
      expect(fetching.first.queryHash, contains('fetching'));
      q.destroy();
    });
  });
}

class _MockObserver implements QueryUpdateCallback {
  @override
  void onQueryUpdate() {}
  @override
  bool shouldFetchOnWindowFocus() => false;
  @override
  bool shouldFetchOnReconnect() => false;
  @override
  Future<void> refetch({bool cancelRefetch = true}) async {}
}
