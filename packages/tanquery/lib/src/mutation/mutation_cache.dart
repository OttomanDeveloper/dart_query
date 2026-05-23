import '../core/notify_manager.dart' as nm;
import '../core/subscribable.dart';
import '../core/focus_manager.dart' as fm;
import '../core/online_manager.dart' as om;
import '../models/mutation_state.dart';
import '../models/types.dart';
import 'mutation.dart';

class MutationCacheEvent {
  final EventType type;
  final Mutation mutation;
  final Object? action;
  final Object? observer;

  const MutationCacheEvent({
    required this.type,
    required this.mutation,
    this.action,
    this.observer,
  });
}

typedef MutationCacheListener = void Function(MutationCacheEvent event);

class MutationCache extends Subscribable<MutationCacheListener> {
  final Set<Mutation> _mutations = {};
  final Map<String, List<Mutation>> _scopes = {};
  int _mutationId = 0;
  final nm.NotifyManager _notifyManager;
  final fm.FocusManager _focusManager;
  final om.OnlineManager _onlineManager;

  final void Function(Object error, Object? variables, Object? context, Mutation mutation)? onError;
  final void Function(Object? data, Object? variables, Object? context, Mutation mutation)? onSuccess;
  final void Function(Object? variables, Mutation mutation)? onMutate;
  final void Function(Object? data, Object? error, Object? variables, Object? context, Mutation mutation)? onSettled;

  MutationCache({
    nm.NotifyManager? notifyManager,
    fm.FocusManager? focusManager,
    om.OnlineManager? onlineManager,
    this.onError,
    this.onSuccess,
    this.onMutate,
    this.onSettled,
  })  : _notifyManager = notifyManager ?? nm.notifyManager,
        _focusManager = focusManager ?? fm.focusManager,
        _onlineManager = onlineManager ?? om.onlineManager;

  Mutation<TData, TVariables> build<TData, TVariables>({
    required MutationConfig<TData, TVariables> config,
    MutationState<TData>? state,
  }) {
    final mutation = Mutation<TData, TVariables>(
      mutationId: ++_mutationId,
      config: config,
      state: state,
      canRunCheck: (m) => canRun(m),
      runNextCallback: (m) => runNext(m),
      cacheNotify: (event) => _handleMutationNotify(event),
      cacheCallbacks: CacheLevelCallbacks(
        onMutate: onMutate != null
            ? (variables, mutation) async => onMutate!(variables, mutation as Mutation)
            : null,
        onSuccess: onSuccess != null
            ? (data, variables, context, mutation) async =>
                onSuccess!(data, variables, context, mutation as Mutation)
            : null,
        onError: onError != null
            ? (error, variables, context, mutation) async =>
                onError!(error, variables, context, mutation as Mutation)
            : null,
        onSettled: onSettled != null
            ? (data, error, variables, context, mutation) async =>
                onSettled!(data, error, variables, context, mutation as Mutation)
            : null,
      ),
      notifyManager: _notifyManager,
      focusManager: _focusManager,
      onlineManager: _onlineManager,
    );
    _add(mutation);
    return mutation;
  }

  void _add(Mutation mutation) {
    _mutations.add(mutation);
    final scopeId = mutation.scope?.id;
    if (scopeId != null) {
      _scopes.putIfAbsent(scopeId, () => []).add(mutation);
    }
    _notify(MutationCacheEvent(type: EventType.added, mutation: mutation));
  }

  void remove(Mutation mutation) {
    _mutations.remove(mutation);
    final scopeId = mutation.scope?.id;
    if (scopeId != null) {
      _scopes[scopeId]?.remove(mutation);
      if (_scopes[scopeId]?.isEmpty ?? false) {
        _scopes.remove(scopeId);
      }
    }
    mutation.destroy();
    _notify(MutationCacheEvent(type: EventType.removed, mutation: mutation));
  }

  bool canRun(Mutation mutation) {
    final scopeId = mutation.scope?.id;
    if (scopeId == null) return true;
    final scopeQueue = _scopes[scopeId] ?? [];
    final firstPending = scopeQueue.cast<Mutation?>().firstWhere(
          (m) => m!.state.isPending,
          orElse: () => null,
        );
    return firstPending == null || identical(firstPending, mutation);
  }

  void runNext(Mutation completedMutation) {
    final scopeId = completedMutation.scope?.id;
    if (scopeId == null) return;
    final scopeQueue = _scopes[scopeId] ?? [];
    final next = scopeQueue.cast<Mutation?>().firstWhere(
          (m) => m!.state.isPaused && !identical(m, completedMutation),
          orElse: () => null,
        );
    next?.continueExecution();
  }

  Future<void> resumePausedMutations() async {
    final paused = getAll().where((m) => m.state.isPaused).toList();
    await Future.wait(
      paused.map((m) async {
        try {
          await m.continueExecution();
        } catch (_) {}
      }),
    );
  }

  List<Mutation> getAll() => _mutations.toList();

  List<Mutation> findAll({
    MutationStatus? status,
    bool Function(Mutation)? predicate,
  }) {
    var results = getAll();
    if (status != null) {
      results = results.where((m) => m.state.status == status).toList();
    }
    if (predicate != null) {
      results = results.where(predicate).toList();
    }
    return results;
  }

  void clear() {
    _notifyManager.batch(() {
      for (final mutation in getAll()) {
        remove(mutation);
      }
    });
  }

  void _notify(MutationCacheEvent event) {
    _notifyManager.batch(() {
      for (final listener in listeners) {
        listener(event);
      }
    });
  }

  void _handleMutationNotify(Map<String, Object?> event) {
    final mutation = event['mutation'] as Mutation;
    final type = event['type'];

    if (type is EventType) {
      _notify(MutationCacheEvent(
        type: type,
        mutation: mutation,
        action: event['action'],
        observer: event['observer'],
      ));
    }

    if (type == 'requestRemove') {
      remove(mutation);
    }
  }
}
