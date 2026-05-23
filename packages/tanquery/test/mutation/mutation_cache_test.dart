import 'dart:async';
import 'package:test/test.dart';
import 'package:tanquery/src/mutation/mutation.dart';
import 'package:tanquery/src/mutation/mutation_cache.dart';
import 'package:tanquery/src/models/types.dart';
import 'package:tanquery/src/core/notify_manager.dart';
import 'package:tanquery/src/core/focus_manager.dart';
import 'package:tanquery/src/core/online_manager.dart';

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

  group('MutationCache — cache-level callbacks', () {
    test('onMutate fires before instance onMutate', () async {
      final order = <String>[];
      final focus = FocusManager()..setFocused(true);
      final online = OnlineManager()..setOnline(true);
      cache = MutationCache(
        notifyManager: notify,
        focusManager: focus,
        onlineManager: online,
        onMutate: (variables, mutation) async => order.add('cache_onMutate'),
      );
      final m = cache.build<String, String>(
        config: MutationConfig(
          mutationFn: (v) async {
            order.add('fn');
            return 'ok';
          },
          onMutate: (v) async {
            order.add('instance_onMutate');
            return null;
          },
        ),
      );
      await m.execute('input');
      expect(order.indexOf('cache_onMutate'), lessThan(order.indexOf('instance_onMutate')));
      expect(order.indexOf('instance_onMutate'), lessThan(order.indexOf('fn')));
    });

    test('onSuccess fires cache-level before instance-level', () async {
      final order = <String>[];
      final focus = FocusManager()..setFocused(true);
      final online = OnlineManager()..setOnline(true);
      cache = MutationCache(
        notifyManager: notify,
        focusManager: focus,
        onlineManager: online,
        onSuccess: (data, vars, ctx, mutation) async => order.add('cache_onSuccess'),
        onSettled: (data, error, vars, ctx, mutation) async => order.add('cache_onSettled'),
      );
      final m = cache.build<String, String>(
        config: MutationConfig(
          mutationFn: (v) async => 'ok',
          onSuccess: (data, v, ctx) async => order.add('instance_onSuccess'),
          onSettled: (data, error, v, ctx) async => order.add('instance_onSettled'),
        ),
      );
      await m.execute('input');
      expect(order, [
        'cache_onSuccess',
        'instance_onSuccess',
        'cache_onSettled',
        'instance_onSettled',
      ]);
    });

    test('onError fires cache-level before instance-level', () async {
      final order = <String>[];
      final focus = FocusManager()..setFocused(true);
      final online = OnlineManager()..setOnline(true);
      cache = MutationCache(
        notifyManager: notify,
        focusManager: focus,
        onlineManager: online,
        onError: (error, vars, ctx, mutation) async => order.add('cache_onError'),
        onSettled: (data, error, vars, ctx, mutation) async => order.add('cache_onSettled'),
      );
      final m = cache.build<String, String>(
        config: MutationConfig(
          mutationFn: (v) async => throw Exception('fail'),
          onError: (error, v, ctx) async => order.add('instance_onError'),
          onSettled: (data, error, v, ctx) async => order.add('instance_onSettled'),
        ),
      );
      try { await m.execute('input'); } catch (_) {}
      expect(order, [
        'cache_onError',
        'instance_onError',
        'cache_onSettled',
        'instance_onSettled',
      ]);
    });
  });

  group('MutationCache — mutationKey and meta', () {
    test('mutation stores mutationKey and meta from config', () {
      final m = cache.build<String, String>(
        config: MutationConfig(
          mutationFn: (v) async => v,
          mutationKey: ['todos', 'create'],
          meta: {'source': 'test'},
        ),
      );
      expect(m.mutationKey, ['todos', 'create']);
      expect(m.meta, {'source': 'test'});
    });
  });
}
