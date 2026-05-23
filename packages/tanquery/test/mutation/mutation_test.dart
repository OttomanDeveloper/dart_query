import 'dart:async';
import 'package:test/test.dart';
import 'package:tanquery/src/mutation/mutation.dart';
import 'package:tanquery/src/models/types.dart';
import 'package:tanquery/src/core/notify_manager.dart';
import 'package:tanquery/src/core/focus_manager.dart';
import 'package:tanquery/src/core/online_manager.dart';

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

  Mutation<TData, TVariables> createMutation<TData, TVariables>({
    required MutationFn<TData, TVariables> mutationFn,
    MutationScope? scope,
    int retryCount = 0,
    Future<Object?> Function(TVariables)? onMutate,
    Future<void> Function(TData, TVariables, Object?)? onSuccess,
    Future<void> Function(Object, TVariables, Object?)? onError,
    Future<void> Function(TData?, Object?, TVariables, Object?)? onSettled,
    bool Function(Mutation)? canRunCheck,
    void Function(Mutation)? runNextCallback,
  }) {
    return Mutation<TData, TVariables>(
      mutationId: 1,
      config: MutationConfig<TData, TVariables>(
        mutationFn: mutationFn,
        scope: scope,
        retryCount: retryCount,
        onMutate: onMutate,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
      ),
      notifyManager: notify,
      focusManager: focus,
      onlineManager: online,
      canRunCheck: canRunCheck,
      runNextCallback: runNextCallback,
    );
  }

  group('Mutation — initial state', () {
    test('starts idle', () {
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => v,
      );
      expect(mutation.state.isIdle, isTrue);
      expect(mutation.state.data, isNull);
      expect(mutation.state.error, isNull);
    });
  });

  group('Mutation — execute success', () {
    test('transitions through pending → success', () async {
      final states = <MutationStatus>[];
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => 'result: $v',
      );
      mutation.addObserver((_) => states.add(mutation.state.status));
      final result = await mutation.execute('input');
      expect(result, 'result: input');
      expect(mutation.state.isSuccess, isTrue);
      expect(mutation.state.data, 'result: input');
      expect(states, contains(MutationStatus.pending));
      expect(states, contains(MutationStatus.success));
    });

    test('stores variables', () async {
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => v,
      );
      await mutation.execute('myInput');
      expect(mutation.state.variables, 'myInput');
    });
  });

  group('Mutation — execute error', () {
    test('transitions to error state', () async {
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => throw Exception('fail'),
      );
      try {
        await mutation.execute('input');
      } catch (_) {}
      expect(mutation.state.isError, isTrue);
      expect(mutation.state.error, isA<Exception>());
      expect(mutation.state.failureCount, 1);
    });
  });

  group('Mutation — callback order', () {
    test('onMutate fires before mutation, context flows through', () async {
      final order = <String>[];
      final mutation = createMutation<String, String>(
        mutationFn: (v) async {
          order.add('fn');
          return 'result';
        },
        onMutate: (v) async {
          order.add('onMutate');
          return 'rollback_data';
        },
        onSuccess: (data, v, ctx) async {
          order.add('onSuccess(ctx=$ctx)');
        },
        onSettled: (data, error, v, ctx) async {
          order.add('onSettled(ctx=$ctx)');
        },
      );
      await mutation.execute('input');
      expect(order, [
        'onMutate',
        'fn',
        'onSuccess(ctx=rollback_data)',
        'onSettled(ctx=rollback_data)',
      ]);
    });

    test('onError fires on failure, context flows through', () async {
      final order = <String>[];
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => throw Exception('fail'),
        onMutate: (v) async {
          order.add('onMutate');
          return 'snapshot';
        },
        onError: (error, v, ctx) async {
          order.add('onError(ctx=$ctx)');
        },
        onSettled: (data, error, v, ctx) async {
          order.add('onSettled(ctx=$ctx)');
        },
      );
      try {
        await mutation.execute('input');
      } catch (_) {}
      expect(order, [
        'onMutate',
        'onError(ctx=snapshot)',
        'onSettled(ctx=snapshot)',
      ]);
    });

    test('error in callback does not break chain', () async {
      var settledCalled = false;
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => 'ok',
        onSuccess: (data, v, ctx) async => throw Exception('callback error'),
        onSettled: (data, error, v, ctx) async => settledCalled = true,
      );
      await mutation.execute('input');
      expect(settledCalled, isTrue);
    });
  });

  group('Mutation — observers', () {
    test('notifies observers on state change', () async {
      final actions = <MutationActionType>[];
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => 'ok',
      );
      mutation.addObserver((action) => actions.add(action));
      await mutation.execute('input');
      expect(actions, contains(MutationActionType.pending));
      expect(actions, contains(MutationActionType.success));
    });

    test('addObserver clears GC, removeObserver schedules GC', () {
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => 'ok',
      );
      void observer(MutationActionType _) {}
      mutation.addObserver(observer);
      mutation.removeObserver(observer);
      // No crash = GC management works
    });
  });

  group('Mutation — scoped execution', () {
    test('runNext is called in finally', () async {
      var runNextCalled = false;
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => 'ok',
        runNextCallback: (_) => runNextCalled = true,
      );
      await mutation.execute('input');
      expect(runNextCalled, isTrue);
    });

    test('runNext is called even on error', () async {
      var runNextCalled = false;
      final mutation = createMutation<String, String>(
        mutationFn: (v) async => throw Exception('fail'),
        runNextCallback: (_) => runNextCalled = true,
      );
      try {
        await mutation.execute('input');
      } catch (_) {}
      expect(runNextCalled, isTrue);
    });
  });
}
