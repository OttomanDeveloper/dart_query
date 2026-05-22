import 'dart:async';
import '../core/notify_manager.dart' as nm;
import '../core/removable.dart';
import '../models/mutation_state.dart';
import '../models/types.dart';
import '../retryer/retryer.dart';
import '../core/focus_manager.dart' as fm;
import '../core/online_manager.dart' as om;

typedef MutationFn<TData, TVariables> = Future<TData> Function(TVariables variables);

class MutationScope {
  final String id;
  const MutationScope({required this.id});
}

class MutationConfig<TData, TVariables> {
  final MutationFn<TData, TVariables> mutationFn;
  final MutationScope? scope;
  final int retryCount;
  final Duration Function(int) retryDelay;
  final NetworkMode networkMode;
  final Future<Object?> Function(TVariables variables)? onMutate;
  final Future<void> Function(TData data, TVariables variables, Object? context)? onSuccess;
  final Future<void> Function(Object error, TVariables variables, Object? context)? onError;
  final Future<void> Function(TData? data, Object? error, TVariables variables, Object? context)? onSettled;

  const MutationConfig({
    required this.mutationFn,
    this.scope,
    this.retryCount = 0,
    this.retryDelay = _defaultDelay,
    this.networkMode = NetworkMode.online,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
  });

  static Duration _defaultDelay(int i) => Duration(milliseconds: 1000 * (1 << i).clamp(1, 30));
}

typedef MutationUpdateCallback = void Function(MutationActionType action);
typedef MutationCacheCallback = void Function(Map<String, Object?> event);

class Mutation<TData, TVariables> extends Removable {
  final int mutationId;
  final MutationConfig<TData, TVariables> config;
  final nm.NotifyManager _notifyManager;
  final fm.FocusManager _focusManager;
  final om.OnlineManager _onlineManager;
  final bool Function(Mutation)? _canRunCheck;
  final void Function(Mutation)? _runNextCallback;
  final MutationCacheCallback? _cacheNotify;

  MutationState<TData> state;
  final List<MutationUpdateCallback> _observers = [];
  Retryer<TData>? _retryer;

  Mutation({
    required this.mutationId,
    required this.config,
    Duration gcTime = const Duration(minutes: 5),
    MutationState<TData>? state,
    bool Function(Mutation)? canRunCheck,
    void Function(Mutation)? runNextCallback,
    MutationCacheCallback? cacheNotify,
    nm.NotifyManager? notifyManager,
    fm.FocusManager? focusManager,
    om.OnlineManager? onlineManager,
  })  : _notifyManager = notifyManager ?? nm.notifyManager,
        _focusManager = focusManager ?? fm.focusManager,
        _onlineManager = onlineManager ?? om.onlineManager,
        _canRunCheck = canRunCheck,
        _runNextCallback = runNextCallback,
        _cacheNotify = cacheNotify,
        state = state ?? MutationState<TData>(),
        super(gcTime: gcTime) {
    scheduleGc();
  }

  MutationScope? get scope => config.scope;

  // --- Observers ---

  void addObserver(MutationUpdateCallback observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
      clearGcTimeout();
      _cacheNotify?.call({
        'mutation': this,
        'type': EventType.observerAdded,
        'observer': observer,
      });
    }
  }

  void removeObserver(MutationUpdateCallback observer) {
    _observers.remove(observer);
    scheduleGc();
    _cacheNotify?.call({
      'mutation': this,
      'type': EventType.observerRemoved,
      'observer': observer,
    });
  }

  // --- Execute ---

  Future<TData> execute(TVariables variables) async {
    final isPaused = !(_canRunCheck?.call(this) ?? true);
    _dispatch(MutationActionType.pending, variables: variables, isPaused: isPaused);

    Object? context;
    try {
      context = await config.onMutate?.call(variables);
    } catch (_) {}
    if (context != null) {
      _dispatch(MutationActionType.pending, variables: variables, context: context, isPaused: isPaused);
    }

    _retryer = Retryer<TData>(
      fn: () => config.mutationFn(variables),
      retryCount: config.retryCount,
      retryDelay: config.retryDelay,
      networkMode: config.networkMode,
      canRun: () => _canRunCheck?.call(this) ?? true,
      onFail: (count, error) =>
          _dispatch(MutationActionType.failed, failureCount: count, error: error),
      onPause: () => _dispatch(MutationActionType.pause),
      onContinue: () => _dispatch(MutationActionType.resume),
      focusManager: _focusManager,
      onlineManager: _onlineManager,
    );

    try {
      final data = await _retryer!.start();

      // Success path — cache-level then instance-level
      try { await config.onSuccess?.call(data, variables, context); } catch (_) {}
      try { await config.onSettled?.call(data, null, variables, context); } catch (_) {}

      _dispatch(MutationActionType.success, data: data);
      return data;
    } catch (error) {
      // Error path — each callback isolated
      try { await config.onError?.call(error, variables, context); } catch (_) {}
      try { await config.onSettled?.call(null, error, variables, context); } catch (_) {}

      _dispatch(MutationActionType.error, error: error);
      rethrow;
    } finally {
      _runNextCallback?.call(this);
    }
  }

  Future<void> continueExecution() async {
    _retryer?.resume();
  }

  // --- State Machine ---

  void _dispatch(
    MutationActionType action, {
    TData? data,
    Object? error,
    TVariables? variables,
    Object? context,
    bool isPaused = false,
    int? failureCount,
  }) {
    state = _reducer(state, action,
        data: data,
        error: error,
        variables: variables,
        context: context,
        isPaused: isPaused,
        failureCount: failureCount);

    _notifyManager.batch(() {
      for (final observer in List.of(_observers)) {
        observer(action);
      }
      _cacheNotify?.call({
        'mutation': this,
        'type': EventType.updated,
        'action': action,
      });
    });
  }

  MutationState<TData> _reducer(
    MutationState<TData> currentState,
    MutationActionType action, {
    TData? data,
    Object? error,
    TVariables? variables,
    Object? context,
    bool isPaused = false,
    int? failureCount,
  }) {
    switch (action) {
      case MutationActionType.pending:
        return MutationState<TData>(
          status: MutationStatus.pending,
          variables: variables,
          context: context ?? currentState.context,
          isPaused: isPaused,
          submittedAt: DateTime.now(),
        );
      case MutationActionType.success:
        return currentState.copyWith(
          data: () => data,
          error: () => null,
          status: MutationStatus.success,
          isPaused: false,
          failureCount: 0,
          failureReason: () => null,
        );
      case MutationActionType.error:
        return currentState.copyWith(
          data: () => null,
          error: () => error,
          status: MutationStatus.error,
          isPaused: false,
          failureCount: currentState.failureCount + 1,
          failureReason: () => error,
        );
      case MutationActionType.failed:
        return currentState.copyWith(
          failureCount: failureCount ?? currentState.failureCount,
          failureReason: () => error,
        );
      case MutationActionType.pause:
        return currentState.copyWith(isPaused: true);
      case MutationActionType.resume:
        return currentState.copyWith(isPaused: false);
    }
  }

  @override
  void optionalRemove() {
    if (_observers.isEmpty) {
      if (state.isPending) {
        scheduleGc();
      } else {
        _cacheNotify?.call({
          'mutation': this,
          'type': 'requestRemove',
        });
      }
    }
  }
}
