import 'dart:async';
import 'package:test/test.dart';
import 'package:dart_query/src/mutation/mutation.dart';
import 'package:dart_query/src/mutation/mutation_cache.dart';
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

  group('MutationCache — build', () {
    test('creates mutation with unique ID', () {
      final m1 = cache.build<String, String>(
        config: MutationConfig(mutationFn: (v) async => v),
      );
      final m2 = cache.build<String, String>(
        config: MutationConfig(mutationFn: (v) async => v),
      );
      expect(m1.mutationId, isNot(m2.mutationId));
      expect(cache.getAll().length, 2);
    });

    test('fires added event', () {
      final events = <MutationCacheEvent>[];
      cache.subscribe((e) => events.add(e));
      cache.build<String, String>(
        config: MutationConfig(mutationFn: (v) async => v),
      );
      expect(events.any((e) => e.type == EventType.added), isTrue);
    });
  });

  group('MutationCache — remove', () {
    test('removes mutation from cache', () {
      final m = cache.build<String, String>(
        config: MutationConfig(mutationFn: (v) async => v),
      );
      cache.remove(m);
      expect(cache.getAll().length, 0);
    });

    test('fires removed event', () {
      final m = cache.build<String, String>(
        config: MutationConfig(mutationFn: (v) async => v),
      );
      final events = <MutationCacheEvent>[];
      cache.subscribe((e) => events.add(e));
      cache.remove(m);
      expect(events.any((e) => e.type == EventType.removed), isTrue);
    });
  });

  group('MutationCache — clear', () {
    test('removes all mutations', () {
      cache.build<String, String>(config: MutationConfig(mutationFn: (v) async => v));
      cache.build<String, String>(config: MutationConfig(mutationFn: (v) async => v));
      cache.clear();
      expect(cache.getAll().length, 0);
    });
  });

  group('MutationCache — findAll', () {
    test('filters by status', () async {
      final m1 = cache.build<String, String>(
        config: MutationConfig(mutationFn: (v) async => v),
      );
      cache.build<String, String>(
        config: MutationConfig(mutationFn: (v) async => v),
      );
      await m1.execute('go');
      final successes = cache.findAll(status: MutationStatus.success);
      expect(successes.length, 1);
    });

    test('filters by predicate', () {
      cache.build<String, String>(config: MutationConfig(mutationFn: (v) async => v));
      cache.build<String, String>(config: MutationConfig(mutationFn: (v) async => v));
      final results = cache.findAll(predicate: (m) => m.mutationId == 1);
      expect(results.length, 1);
    });
  });

  group('MutationCache — scoped execution', () {
    test('canRun returns true for unscoped mutations', () {
      final m = cache.build<String, String>(
        config: MutationConfig(mutationFn: (v) async => v),
      );
      expect(cache.canRun(m), isTrue);
    });

    test('canRun blocks second scoped mutation while first is pending', () async {
      final scope = MutationScope(id: 'scope1');
      final completer1 = Completer<String>();

      final m1 = cache.build<String, String>(
        config: MutationConfig(
          mutationFn: (v) => completer1.future,
          scope: scope,
        ),
      );
      final m2 = cache.build<String, String>(
        config: MutationConfig(
          mutationFn: (v) async => 'second',
          scope: scope,
        ),
      );

      // Start m1
      unawaited(m1.execute('first').catchError((_) => ''));
      await Future.delayed(Duration.zero);

      // m1 is pending, m2 should be blocked
      expect(m1.state.isPending, isTrue);
      expect(cache.canRun(m1), isTrue);
      expect(cache.canRun(m2), isFalse);

      // Complete m1
      completer1.complete('first');
      await Future.delayed(Duration.zero);
    });

    test('mutations in different scopes run independently', () {
      final m1 = cache.build<String, String>(
        config: MutationConfig(
          mutationFn: (v) async => v,
          scope: MutationScope(id: 'a'),
        ),
      );
      final m2 = cache.build<String, String>(
        config: MutationConfig(
          mutationFn: (v) async => v,
          scope: MutationScope(id: 'b'),
        ),
      );
      expect(cache.canRun(m1), isTrue);
      expect(cache.canRun(m2), isTrue);
    });
  });
}
