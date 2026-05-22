import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:dart_query/src/query/query.dart';
import 'package:dart_query/src/models/query_key.dart';
import 'package:dart_query/src/models/query_state.dart';
import 'package:dart_query/src/models/types.dart';
import 'package:dart_query/src/core/cancelled_error.dart';
import 'package:dart_query/src/core/focus_manager.dart';
import 'package:dart_query/src/core/online_manager.dart';
import 'package:dart_query/src/core/notify_manager.dart';

class MockObserver implements QueryUpdateCallback {
  int updateCount = 0;
  @override
  void onQueryUpdate() => updateCount++;
}

void main() {
  late NotifyManager notify;
  late FocusManager focus;
  late OnlineManager online;

  setUp(() {
    notify = NotifyManager();
    notify.setScheduler((cb) => cb());
    focus = FocusManager();
    focus.setFocused(true);
    online = OnlineManager();
    online.setOnline(true);
  });

  Query<T> createQuery<T>({
    List<Object?> key = const ['test'],
    Future<T> Function()? fn,
    T? initialData,
    Duration gcTime = const Duration(minutes: 5),
    int retryCount = 0,
    NetworkMode networkMode = NetworkMode.always,
  }) {
    final queryKey = QueryKey(key);
    return Query<T>(
      queryKey: queryKey,
      queryHash: queryKey.queryHash,
      queryFn: fn,
      initialData: initialData,
      gcTime: gcTime,
      retryCount: retryCount,
      networkMode: networkMode,
      notifyManager: notify,
      focusManager: focus,
      onlineManager: online,
    );
  }

  group('Query — initial state', () {
    test('no data: pending + idle', () {
      final query = createQuery<String>();
      expect(query.state.status, QueryStatus.pending);
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.data, isNull);
    });

    test('with initialData: success', () {
      final query = createQuery<String>(initialData: 'hello');
      expect(query.state.status, QueryStatus.success);
      expect(query.state.data, 'hello');
      expect(query.state.dataUpdatedAt, isNotNull);
    });
  });

  group('Query — setData', () {
    test('dispatches success action', () {
      final query = createQuery<String>();
      query.setData('hello');
      expect(query.state.status, QueryStatus.success);
      expect(query.state.data, 'hello');
      expect(query.state.isInvalidated, isFalse);
      expect(query.state.dataUpdateCount, 1);
    });

    test('notifies observers', () {
      final query = createQuery<String>();
      final observer = MockObserver();
      query.addObserver(observer);
      query.setData('hello');
      expect(observer.updateCount, 1);
    });
  });

  group('Query — invalidate', () {
    test('marks as invalidated', () {
      final query = createQuery<String>(initialData: 'data');
      query.invalidate();
      expect(query.state.isInvalidated, isTrue);
    });

    test('idempotent', () {
      final query = createQuery<String>(initialData: 'data');
      final observer = MockObserver();
      query.addObserver(observer);
      query.invalidate();
      query.invalidate();
      expect(observer.updateCount, 1);
    });
  });

  group('Query — staleness', () {
    test('no data is always stale', () {
      final query = createQuery<String>();
      expect(query.isStaleByTime(const Duration(hours: 1)), isTrue);
    });

    test('fresh data is not stale', () {
      final query = createQuery<String>(initialData: 'data');
      expect(query.isStaleByTime(const Duration(hours: 1)), isFalse);
    });

    test('zero staleTime is immediately stale', () {
      final query = createQuery<String>(initialData: 'data');
      expect(query.isStaleByTime(Duration.zero), isTrue);
    });

    test('invalidated data is stale regardless of time', () {
      final query = createQuery<String>(initialData: 'data');
      query.invalidate();
      expect(query.isStaleByTime(const Duration(hours: 1)), isTrue);
    });
  });

  group('Query — observer management', () {
    test('addObserver prevents GC', () {
      fakeAsync((async) {
        final query = createQuery<String>(gcTime: const Duration(seconds: 5));
        var removed = false;
        query.onRemove = () => removed = true;
        query.scheduleGc();
        query.addObserver(MockObserver());
        async.elapse(const Duration(seconds: 10));
        expect(removed, isFalse);
      });
    });

    test('removeObserver schedules GC', () {
      fakeAsync((async) {
        final query = createQuery<String>(gcTime: const Duration(seconds: 5));
        var removed = false;
        query.onRemove = () => removed = true;
        final observer = MockObserver();
        query.addObserver(observer);
        query.removeObserver(observer);
        async.elapse(const Duration(seconds: 5));
        expect(removed, isTrue);
      });
    });

    test('isActive when has observers', () {
      final query = createQuery<String>();
      expect(query.isActive(), isFalse);
      query.addObserver(MockObserver());
      expect(query.isActive(), isTrue);
    });
  });

  group('Query — fetch', () {
    test('successful fetch updates state to success', () async {
      final query = createQuery<String>(fn: () async => 'fetched');
      await query.fetch();
      expect(query.state.status, QueryStatus.success);
      expect(query.state.data, 'fetched');
      expect(query.state.fetchStatus, FetchStatus.idle);
    });

    test('failed fetch updates state to error', () async {
      final query = createQuery<String>(
        fn: () async => throw Exception('fail'),
      );
      try {
        await query.fetch();
      } catch (_) {}
      expect(query.state.status, QueryStatus.error);
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.isInvalidated, isTrue);
    });

    test('fetch deduplication: returns same promise if already fetching', () async {
      final completer = Completer<String>();
      final query = createQuery<String>(fn: () => completer.future);
      final future1 = query.fetch(cancelRefetch: false);
      final future2 = query.fetch(cancelRefetch: false);
      completer.complete('done');
      final result1 = await future1;
      final result2 = await future2;
      expect(result1, 'done');
      expect(result2, 'done');
    });

    test('fetch with cancelRefetch cancels previous fetch', () async {
      var fetchCount = 0;
      final completer1 = Completer<String>();
      final query = createQuery<String>(
        initialData: 'old',
        fn: () {
          fetchCount++;
          if (fetchCount == 1) return completer1.future;
          return Future.value('new');
        },
      );
      final future1 = query.fetch(cancelRefetch: false);
      final future2 = query.fetch(cancelRefetch: true);
      completer1.complete('should be ignored');
      await future2;
      expect(query.state.data, 'new');
    });

    test('setState overrides state directly', () {
      final query = createQuery<String>();
      query.setState(QueryState<String>(
        status: QueryStatus.success,
        data: 'manual',
        dataUpdatedAt: DateTime.now(),
        dataUpdateCount: 1,
      ));
      expect(query.state.data, 'manual');
      expect(query.state.status, QueryStatus.success);
    });

    test('cancel rejects in-flight fetch', () async {
      final completer = Completer<String>();
      final query = createQuery<String>(fn: () => completer.future);
      unawaited(query.fetch().catchError((_) => ''));
      await query.cancel();
      expect(query.state.fetchStatus, FetchStatus.idle);
    });

    test('reset restores initial state', () {
      final query = createQuery<String>(initialData: 'original');
      query.setData('changed');
      expect(query.state.data, 'changed');
      query.reset();
      expect(query.state.data, 'original');
      expect(query.state.status, QueryStatus.success);
    });

    test('isFetched returns true after successful fetch', () async {
      final query = createQuery<String>(fn: () async => 'data');
      expect(query.isFetched(), isFalse);
      await query.fetch();
      expect(query.isFetched(), isTrue);
    });

    test('isFetched returns true after failed fetch', () async {
      final query = createQuery<String>(
        fn: () async => throw Exception('fail'),
      );
      try {
        await query.fetch();
      } catch (_) {}
      expect(query.isFetched(), isTrue);
    });
  });

  group('Query — focus/online events', () {
    test('onFocus resumes paused retryer', () async {
      online.setOnline(false);
      final query = createQuery<String>(
        fn: () async => 'data',
        networkMode: NetworkMode.online,
      );
      final future = query.fetch();
      await Future.delayed(Duration.zero);
      expect(query.state.fetchStatus, FetchStatus.paused);

      online.setOnline(true);
      query.onOnline();
      final result = await future;
      expect(result, 'data');
    });
  });
}
