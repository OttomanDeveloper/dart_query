# dart_query

[![pub package](https://img.shields.io/pub/v/dart_query.svg)](https://pub.dev/packages/dart_query)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Dart 3](https://img.shields.io/badge/Dart-3.5+-0175C2.svg)](https://dart.dev)

**TanStack Query for Dart.** Stop writing the same fetch-cache-retry-loading-error boilerplate in every project. `dart_query` handles caching, background refetching, retries, and state management so you can focus on building features.

Pure Dart -- zero Flutter dependency. Works with Shelf, Dart Frog, CLI tools, or any Dart environment.

---

## Table of Contents

- [The Problem](#the-problem)
- [Installation](#installation)
- [Quick Start (5 minutes)](#quick-start-5-minutes)
- [Core Concepts](#core-concepts)
- [Queries](#queries)
- [Mutations](#mutations)
- [Query Keys](#query-keys)
- [Stale Time & Caching](#stale-time--caching)
- [Retry & Error Handling](#retry--error-handling)
- [Advanced](#advanced)
- [API Reference](#api-reference)
- [Architecture](#architecture)
- [For Flutter](#for-flutter)

---

## The Problem

Every Dart app that fetches data ends up writing the same code:

```dart
// Without dart_query -- you write this in EVERY screen
class TodoService {
  List<Todo>? _cache;
  DateTime? _lastFetch;
  bool _isLoading = false;
  Object? _error;
  int _retryCount = 0;

  Future<List<Todo>> getTodos() async {
    if (_cache != null && DateTime.now().difference(_lastFetch!) < Duration(minutes: 5)) {
      return _cache!; // Return cached data
    }
    _isLoading = true;
    try {
      final todos = await api.fetchTodos();
      _cache = todos;
      _lastFetch = DateTime.now();
      _retryCount = 0;
      return todos;
    } catch (e) {
      _error = e;
      if (_retryCount < 3) {
        _retryCount++;
        await Future.delayed(Duration(seconds: _retryCount * 2));
        return getTodos(); // retry
      }
      rethrow;
    } finally {
      _isLoading = false;
    }
  }
}
// Then repeat for users, posts, comments, settings...
```

**With dart_query, all of that becomes:**

```dart
final todos = await client.fetchQuery<List<Todo>>(
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
);
// Caching, retries, deduplication, staleness -- all handled automatically.
```

You get automatic caching, stale-while-revalidate, exponential backoff retries, request deduplication, and garbage collection. For free. On every query.

---

## Installation

```yaml
dependencies:
  dart_query: ^0.1.0
```

```bash
dart pub get
```

> **Flutter users:** You probably want [`dart_query_flutter`](https://pub.dev/packages/dart_query_flutter) instead, which includes widget builders like `QueryBuilder`. This package is the pure Dart core.

---

## Quick Start (5 minutes)

### Step 1: Create a QueryClient

The `QueryClient` is your central hub. Create one and mount it:

```dart
import 'package:dart_query/dart_query.dart';

final client = QueryClient();
client.mount(); // Starts listening for focus/connectivity changes
```

### Step 2: Fetch data

```dart
final todos = await client.fetchQuery<List<Todo>>(
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
);
print(todos); // Your data, automatically cached
```

### Step 3: Read from cache

```dart
// Instant -- no network call
final cached = client.getQueryData<List<Todo>>(QueryKey(['todos']));
```

### Step 4: Invalidate when data changes

```dart
// Marks 'todos' as stale and triggers a background refetch
await client.invalidateQueries(queryKey: QueryKey(['todos']));
```

That's it. You now have a fully cached, auto-retrying data layer.

---

## Core Concepts

### How Caching Works

When you fetch with `dart_query`, this happens automatically:

```
1. First fetch    --> Network request --> Cache result --> Return data
2. Second fetch   --> Return cached data instantly (no network)
3. After staleTime --> Next access triggers background refetch
4. While refetching --> Show cached data + fetch silently in background
5. No observers   --> Start GC timer --> Remove from cache after gcTime
```

This pattern is called **stale-while-revalidate**: your UI always has data to show, and it's always fresh (or refreshing).

### Two-Axis State Model

Every query has TWO independent state axes:

| Axis | Values | What it means |
|---|---|---|
| **QueryStatus** | `pending`, `success`, `error` | Do we have data? |
| **FetchStatus** | `fetching`, `paused`, `idle` | Is a network request happening? |

This lets you distinguish between:
- **Loading** (`pending` + `fetching`): First load, no data yet, show spinner
- **Background refetch** (`success` + `fetching`): Have data, showing it, silently refreshing
- **Error with stale data** (`error` + `idle`): Fetch failed but we still have the old data

```dart
final result = observer.currentResult;
if (result.isLoading) print('First load...');
if (result.isFetching && result.isSuccess) print('Refreshing in background...');
if (result.isError && result.data != null) print('Error, but showing stale: ${result.data}');
```

---

## Queries

### Basic Query

```dart
final data = await client.fetchQuery<User>(
  queryKey: QueryKey(['user', userId]),
  queryFn: () => api.fetchUser(userId),
);
```

### Reactive Query (with observer)

For reactive updates (like in a UI), use `QueryObserver`:

```dart
final observer = QueryObserver<List<Todo>>(
  cache: client.getQueryCache(),
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
  staleTime: Duration(minutes: 5),
);

// Subscribe to changes
final unsubscribe = observer.subscribe((result) {
  print('Status: ${result.status}');
  print('Data: ${result.data}');
  print('Error: ${result.error}');
  print('Is loading: ${result.isLoading}');
  print('Is fetching: ${result.isFetching}');
});

// Later: clean up
unsubscribe();
```

### Prefetching

Fetch data before the user needs it:

```dart
// User is on the list page -- prefetch the detail page
await client.prefetchQuery<Todo>(
  queryKey: QueryKey(['todo', nextTodoId]),
  queryFn: () => api.fetchTodo(nextTodoId),
);
// When they navigate, data is already cached -- instant display
```

### Dependent Queries

Chain queries where one depends on another:

```dart
final userObserver = QueryObserver<User>(
  cache: client.getQueryCache(),
  queryKey: QueryKey(['user']),
  queryFn: () => api.fetchUser(),
);

final todosObserver = QueryObserver<List<Todo>>(
  cache: client.getQueryCache(),
  queryKey: QueryKey(['todos', user?.id]),
  queryFn: () => api.fetchTodosByUser(user!.id),
  enabled: user != null, // Won't fetch until user data is available
);
```

### Placeholder Data

Show something while the real data loads:

```dart
final observer = QueryObserver<List<Todo>>(
  cache: client.getQueryCache(),
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
  placeholderData: [], // Show empty list while loading
);
```

Or use previous query data for smooth transitions:

```dart
// When switching filters, show old filter's data while fetching new
final observer = QueryObserver<List<Todo>>(
  cache: client.getQueryCache(),
  queryKey: QueryKey(['todos', currentFilter]),
  queryFn: () => api.fetchTodos(filter: currentFilter),
  placeholderDataFn: (previousData, previousQuery) => previousData,
);
// result.isPlaceholderData tells you if showing old data
```

### Select (Transform Data)

Transform the raw response before it reaches your code:

```dart
final observer = QueryObserver<String>(
  cache: client.getQueryCache(),
  queryKey: QueryKey(['user']),
  queryFn: () => api.fetchUser(), // returns User
  select: (User user) => user.displayName, // transforms to String
);
// observer.currentResult.data is now a String, not a User
```

The select function is memoized -- it won't re-run if the raw data hasn't changed.

---

## Mutations

Mutations are for **creating, updating, or deleting** data on the server.

### Basic Mutation

```dart
final observer = MutationObserver<Todo, CreateTodoInput>(
  cache: client.getMutationCache(),
  config: MutationConfig(
    mutationFn: (input) => api.createTodo(input),
  ),
);

// Fire and forget
observer.mutate(CreateTodoInput(title: 'Buy milk'));

// Or await the result
final newTodo = await observer.mutateAsync(CreateTodoInput(title: 'Buy milk'));
```

### Mutation with Cache Invalidation

After a mutation succeeds, invalidate related queries so they refetch:

```dart
final observer = MutationObserver<Todo, CreateTodoInput>(
  cache: client.getMutationCache(),
  config: MutationConfig(
    mutationFn: (input) => api.createTodo(input),
    onSuccess: (data, variables, context) async {
      // This triggers all 'todos' queries to refetch
      await client.invalidateQueries(queryKey: QueryKey(['todos']));
    },
  ),
);
```

### Optimistic Updates

Update the UI before the server responds. Roll back if it fails:

```dart
final observer = MutationObserver<Todo, CreateTodoInput>(
  cache: client.getMutationCache(),
  config: MutationConfig(
    mutationFn: (input) => api.createTodo(input),
    onMutate: (input) async {
      // Save current state for rollback
      final previous = client.getQueryData<List<Todo>>(QueryKey(['todos']));

      // Optimistically add the new todo
      client.setQueryData<List<Todo>>(
        QueryKey(['todos']),
        (List<Todo> old) => [...old, Todo.fromInput(input)],
      );

      return previous; // This becomes 'context' in onError
    },
    onError: (error, variables, context) async {
      // Roll back to previous state
      if (context != null) {
        client.setQueryData<List<Todo>>(QueryKey(['todos']), context);
      }
    },
    onSettled: (data, error, variables, context) async {
      // Always refetch to ensure consistency
      await client.invalidateQueries(queryKey: QueryKey(['todos']));
    },
  ),
);
```

### Mutation Callback Order

Callbacks fire in this exact order (matching TanStack Query):

```
1. onMutate(variables)           -- optimistic update, return rollback data
2. mutationFn(variables)         -- the actual API call
3. onSuccess/onError(...)        -- handle result
4. onSettled(...)                 -- cleanup (fires on both success and error)
```

---

## Query Keys

Query keys are how `dart_query` identifies and organizes cached data.

### Simple Keys

```dart
QueryKey(['todos'])           // All todos
QueryKey(['user'])            // Current user
```

### Parameterized Keys

```dart
QueryKey(['todo', 42])        // Todo with id 42
QueryKey(['user', 'abc123'])  // User with id abc123
```

### Hierarchical Invalidation

This is where query keys become powerful. Invalidation uses **prefix matching**:

```dart
// These are all in cache:
QueryKey(['todos'])
QueryKey(['todos', 1])
QueryKey(['todos', 2])
QueryKey(['todos', 'list', {'status': 'active'}])

// This ONE call invalidates ALL of the above:
await client.invalidateQueries(queryKey: QueryKey(['todos']));

// This only invalidates todos with id 1:
await client.invalidateQueries(queryKey: QueryKey(['todos', 1]), exact: true);
```

Think of it like a file system: invalidating a folder invalidates everything inside it.

---

## Stale Time & Caching

### staleTime -- How long is data "fresh"?

```dart
QueryObserver<User>(
  // ...
  staleTime: Duration(minutes: 5), // Data is fresh for 5 minutes
);
```

- `Duration.zero` (default): Data is stale immediately. Every new subscriber triggers a refetch.
- `Duration(minutes: 5)`: Data is fresh for 5 minutes. No refetches during that window.
- `StaleTime.static_`: Data is **never** stale. Only manual invalidation triggers refetch.

### gcTime -- How long does unused data stay in memory?

```dart
QueryObserver<User>(
  // ...
  gcTime: Duration(minutes: 30), // Keep in cache for 30 min after last subscriber leaves
);
```

Default: 5 minutes. After the last observer unsubscribes, the query stays in cache for `gcTime` before being garbage collected.

### The Lifecycle

```
Subscribe (fresh) --> Show cached data, no refetch
Subscribe (stale) --> Show cached data, refetch in background
Unsubscribe       --> Start gcTime countdown
gcTime expires    --> Remove from cache
New subscribe     --> Full fetch (data was removed)
```

---

## Retry & Error Handling

### Automatic Retries

Queries retry 3 times by default with exponential backoff:

| Attempt | Delay |
|---------|-------|
| 1st retry | 1 second |
| 2nd retry | 2 seconds |
| 3rd retry | 4 seconds |
| Max | 30 seconds (cap) |

```dart
// Customize retry behavior
QueryObserver<User>(
  // ...
  retryCount: 5,              // retry up to 5 times
);
```

Mutations do NOT retry by default (`retryCount: 0`).

### Network Modes

```dart
QueryObserver<User>(
  // ...
  networkMode: NetworkMode.online,      // Only fetch when online (default)
  // networkMode: NetworkMode.always,   // Fetch regardless of network
  // networkMode: NetworkMode.offlineFirst, // Try once offline, pause for retry
);
```

---

## Advanced

### Streamed Queries (WebSocket, SSE, LLM Streaming)

For real-time data sources that send chunks over time:

```dart
final queryFn = streamedQuery<ChatMessage, List<ChatMessage>>(
  streamFn: () => chatApi.messageStream(roomId),
  reducer: (accumulated, chunk) => [...accumulated, chunk],
  initialValue: [],
  refetchMode: RefetchMode.append, // Keep existing messages, add new ones
  onData: (messages) {
    // Called after each chunk -- use for progressive UI updates
    print('${messages.length} messages so far');
  },
);

// Use it like any other query
final observer = QueryObserver<List<ChatMessage>>(
  cache: client.getQueryCache(),
  queryKey: QueryKey(['chat', roomId]),
  queryFn: queryFn,
);
```

**Refetch modes:**
- `RefetchMode.reset` (default): Clear existing data, start fresh
- `RefetchMode.append`: Keep existing data, append new chunks
- `RefetchMode.replace`: Accumulate silently, swap all at once when stream ends

### Hydration (Cache Persistence)

Save the cache to disk and restore it on next app launch:

```dart
// Save cache (e.g., on app pause)
final state = dehydrate(client);
final json = state.toJson();
await prefs.setString('query_cache', jsonEncode(json));

// Restore cache (e.g., on app startup)
final savedJson = jsonDecode(prefs.getString('query_cache')!);
hydrate(client, DehydratedState.fromJson(savedJson));
```

Only successful queries are saved by default. Errors are redacted for security.

### Request Deduplication

Multiple subscribers requesting the same data at the same time get a single network request:

```dart
// These fire ONE network request, not three
final future1 = client.fetchQuery(queryKey: QueryKey(['todos']), queryFn: fetchTodos);
final future2 = client.fetchQuery(queryKey: QueryKey(['todos']), queryFn: fetchTodos);
final future3 = client.fetchQuery(queryKey: QueryKey(['todos']), queryFn: fetchTodos);

// All three resolve with the same data
```

### Structural Sharing

When data is refetched, `dart_query` preserves reference identity for unchanged parts:

```dart
// Old data: {'users': [User(1, 'Alice'), User(2, 'Bob')], 'count': 2}
// New data: {'users': [User(1, 'Alice'), User(2, 'Bobby')], 'count': 2}
// Result: 'count' keeps the old reference, 'users[0]' keeps the old reference
// Only 'users[1]' is a new object
```

This means `identical(oldData.users[0], newData.users[0])` is `true`. Useful for avoiding unnecessary widget rebuilds in Flutter.

---

## API Reference

### QueryClient

| Method | Description |
|---|---|
| `mount()` / `unmount()` | Start/stop listening to focus and connectivity events |
| `fetchQuery(queryKey, queryFn)` | Fetch data (returns cached if fresh) |
| `prefetchQuery(queryKey, queryFn)` | Fetch in background, swallow errors |
| `ensureQueryData(queryKey, queryFn)` | Return cached or fetch if missing |
| `getQueryData(queryKey)` | Read cached data (synchronous, no fetch) |
| `setQueryData(queryKey, data)` | Write to cache manually |
| `invalidateQueries(queryKey)` | Mark as stale + trigger refetch |
| `refetchQueries(queryKey)` | Force refetch regardless of staleness |
| `cancelQueries(queryKey)` | Cancel in-flight fetches |
| `removeQueries(queryKey)` | Remove from cache entirely |
| `resetQueries(queryKey)` | Reset to initial state |
| `clear()` | Clear all caches |
| `isFetching()` | Count of currently fetching queries |
| `isMutating()` | Count of currently pending mutations |

### QueryObserverResult

| Property | Type | Description |
|---|---|---|
| `data` | `T?` | The cached data (null if not yet fetched) |
| `error` | `Object?` | The error if fetch failed |
| `status` | `QueryStatus` | `pending`, `success`, or `error` |
| `fetchStatus` | `FetchStatus` | `fetching`, `paused`, or `idle` |
| `isLoading` | `bool` | First load (no data + fetching) |
| `isFetching` | `bool` | Any network activity (including background) |
| `isSuccess` | `bool` | Data available |
| `isError` | `bool` | Fetch failed |
| `isStale` | `bool` | Data is past staleTime |
| `isPlaceholderData` | `bool` | Showing placeholder, not real data |
| `isFetched` | `bool` | At least one fetch has completed |
| `isRefetching` | `bool` | Refetching with existing data |
| `isLoadingError` | `bool` | Error with no data at all |
| `isRefetchError` | `bool` | Error but still have stale data |
| `dataUpdatedAt` | `DateTime?` | When data was last updated |

---

## Architecture

Faithfully follows [TanStack Query](https://tanstack.com/query)'s internal architecture, analyzed from all 8,698 lines of TanStack source code:

```
QueryClient (public API -- the only class you interact with)
|
+-- QueryCache (stores Query instances by key hash)
|   +-- Query (state machine with 8-action reducer)
|   |   +-- Retryer (exponential backoff, pause/continue/cancel)
|   +-- QueryObserver (bridges Query state to your UI/code)
|
+-- MutationCache (scoped sequential execution)
|   +-- Mutation (state machine with exact callback ordering)
|   +-- MutationObserver (manages mutation lifecycle)
|
+-- FocusManager (app visibility -- triggers refetch on focus)
+-- OnlineManager (network connectivity -- pauses/resumes fetches)
+-- NotifyManager (batches notifications to prevent thrashing)
```

---

## For Flutter

For Flutter widget builders (`QueryBuilder`, `MutationBuilder`, `InfiniteQueryBuilder`) and the visual devtools overlay, see:

- [`dart_query_flutter`](https://pub.dev/packages/dart_query_flutter) -- Widget builders
- [`dart_query_devtools`](https://pub.dev/packages/dart_query_devtools) -- Visual cache inspector

---

## Comparison: Before & After

| Without dart_query | With dart_query |
|---|---|
| Manual cache Map per service | Automatic cache with configurable TTL |
| Custom retry logic everywhere | Built-in exponential backoff (1s-30s) |
| No request deduplication | Same key = one network call |
| Manual loading/error states | Two-axis state model (status + fetchStatus) |
| No background refetch | Auto-refetch on focus, reconnect, interval |
| No cache invalidation | Hierarchical key invalidation |
| No garbage collection | Automatic GC with configurable gcTime |
| ~50 lines per data source | ~5 lines per data source |

---

## License

MIT
