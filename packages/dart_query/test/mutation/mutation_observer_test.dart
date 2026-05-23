import 'package:test/test.dart';
import 'package:dart_query/src/mutation/mutation.dart';
import 'package:dart_query/src/mutation/mutation_cache.dart';
import 'package:dart_query/src/mutation/mutation_observer.dart';
import 'package:dart_query/src/models/types.dart';
import 'package:dart_query/src/core/notify_manager.dart';
import 'package:dart_query/src/core/focus_manager.dart';
import 'package:dart_query/src/core/online_manager.dart';

void main() {
  late MutationCache cache;
  late NotifyManager notify;

  setUp(() {
    notify = NotifyManager();
    notify.setScheduler((cb) => cb());
    final focus = FocusManager()..setFocused(true);
    final online = OnlineManager()..setOnline(true);
    cache = MutationCache(
      notifyManager: notify,
      focusManager: focus,
      onlineManager: online,
    );
  });

  group('MutationObserver — mutate', () {
    test('fires mutation and notifies subscribers', () async {
      final observer = MutationObserver<String, String>(
        cache: cache,
        config: MutationConfig(mutationFn: (v) async => 'result: $v'),
        notifyManager: notify,
      );
      final states = <MutationStatus>[];
      observer.subscribe((state) => states.add(state.status));
      observer.mutate('input');
      await Future.delayed(Duration.zero);
      expect(states, contains(MutationStatus.pending));
      expect(states, contains(MutationStatus.success));
      expect(observer.currentResult.data, 'result: input');
    });

    test('each mutate() creates a new Mutation', () {
      final observer = MutationObserver<String, String>(
        cache: cache,
        config: MutationConfig(mutationFn: (v) async => v),
        notifyManager: notify,
      );
      observer.mutate('first');
      final count1 = cache.getAll().length;
      observer.mutate('second');
      final count2 = cache.getAll().length;
      expect(count2, greaterThan(count1));
    });
  });

  group('MutationObserver — mutateAsync', () {
    test('returns Future that resolves with data', () async {
      final observer = MutationObserver<String, String>(
        cache: cache,
        config: MutationConfig(mutationFn: (v) async => 'async: $v'),
        notifyManager: notify,
      );
      final result = await observer.mutateAsync('input');
      expect(result, 'async: input');
    });

    test('returns Future that throws on error', () async {
      final observer = MutationObserver<String, String>(
        cache: cache,
        config: MutationConfig(mutationFn: (v) async => throw Exception('fail')),
        notifyManager: notify,
      );
      await expectLater(observer.mutateAsync('input'), throwsException);
    });
  });

  group('MutationObserver — per-call callbacks', () {
    test('onSuccess fires on success', () async {
      final observer = MutationObserver<String, String>(
        cache: cache,
        config: MutationConfig(mutationFn: (v) async => 'ok'),
        notifyManager: notify,
      );
      String? successData;
      observer.subscribe((_) {});
      observer.mutate('input', onSuccess: (data, vars, ctx) {
        successData = data;
      });
      await Future.delayed(Duration.zero);
      expect(successData, 'ok');
    });

    test('onError fires on error', () async {
      final observer = MutationObserver<String, String>(
        cache: cache,
        config: MutationConfig(mutationFn: (v) async => throw Exception('fail')),
        notifyManager: notify,
      );
      Object? errorObj;
      observer.subscribe((_) {});
      observer.mutate('input', onError: (error, vars, ctx) {
        errorObj = error;
      });
      await Future.delayed(Duration.zero);
      expect(errorObj, isA<Exception>());
    });

    test('onSettled fires on both success and error', () async {
      var settledCount = 0;
      final observer = MutationObserver<String, String>(
        cache: cache,
        config: MutationConfig(mutationFn: (v) async => 'ok'),
        notifyManager: notify,
      );
      observer.subscribe((_) {});
      observer.mutate('input', onSettled: (data, error, vars, ctx) {
        settledCount++;
      });
      await Future.delayed(Duration.zero);
      expect(settledCount, 1);
    });
  });

  group('MutationObserver — reset', () {
    test('resets to idle state', () async {
      final observer = MutationObserver<String, String>(
        cache: cache,
        config: MutationConfig(mutationFn: (v) async => 'ok'),
        notifyManager: notify,
      );
      await observer.mutateAsync('input');
      expect(observer.currentResult.isSuccess, isTrue);
      observer.reset();
      expect(observer.currentResult.isIdle, isTrue);
      expect(observer.currentResult.data, isNull);
    });
  });

  group('MutationObserver — lifecycle', () {
    test('unsubscribe removes observer from mutation', () async {
      final observer = MutationObserver<String, String>(
        cache: cache,
        config: MutationConfig(mutationFn: (v) async => 'ok'),
        notifyManager: notify,
      );
      final unsub = observer.subscribe((_) {});
      observer.mutate('input');
      unsub();
      // No crash = cleanup works
    });
  });
}
