# tanquery_flutter

[![pub package](https://img.shields.io/pub/v/tanquery_flutter.svg)](https://pub.dev/packages/tanquery_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter 3](https://img.shields.io/badge/Flutter-3.0+-02569B.svg)](https://flutter.dev)

**Flutter adapter for [tanquery](https://pub.dev/packages/tanquery).** Drop-in widget builders that replace your `FutureBuilder` + loading + error + retry boilerplate with one widget.

---

## Table of Contents

- [The Problem](#the-problem)
- [Installation](#installation)
- [Quick Start (3 minutes)](#quick-start-3-minutes)
- [QueryBuilder](#querybuilder)
- [MutationBuilder](#mutationbuilder)
- [InfiniteQueryBuilder](#infinitequerybuilder)
- [QueriesBuilder](#queriesbuilder)
- [Common Patterns](#common-patterns)
- [API Reference](#api-reference)

---

## The Problem

Every Flutter screen that loads data looks like this:

```dart
// Without tanquery_flutter -- repeated on every screen
class TodoScreen extends StatefulWidget { ... }

class _TodoScreenState extends State<TodoScreen> {
  late Future<List<Todo>> _future;
  bool _isLoading = true;
  Object? _error;
  List<Todo>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await api.fetchTodos();
      setState(() { _data = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return CircularProgressIndicator();
    if (_error != null) return Text('Error: $_error');
    return ListView(children: _data!.map(TodoTile.new).toList());
  }
}
```

**With tanquery_flutter:**

```dart
// That entire class becomes:
QueryBuilder<List<Todo>>(
  queryKey: QueryKey(['todos']),
  queryFn: () => api.fetchTodos(),
  builder: (context, state) {
    if (state.isLoading) return CircularProgressIndicator();
    if (state.isError) return Text('Error: ${state.error}');
    return ListView(children: state.data!.map(TodoTile.new).toList());
  },
)
```

And you get caching, retries, background refetching, and deduplication for free.

---

## Installation

```yaml
dependencies:
  tanquery_flutter: ^0.1.0
```

```bash
flutter pub get
```

This package re-exports `tanquery`, so you only need this one import:

```dart
import 'package:tanquery_flutter/tanquery_flutter.dart';
```

---

## Quick Start (3 minutes)

### Step 1: Wrap your app with DartQueryProvider

```dart
import 'package:tanquery_flutter/tanquery_flutter.dart';

void main() {
  final queryClient = QueryClient();

  runApp(
    DartQueryProvider(
      client: queryClient,
      child: MaterialApp(home: HomeScreen()),
    ),
  );
}
```

`DartQueryProvider` automatically:
- Mounts the `QueryClient` lifecycle
- Detects app focus changes (refetch when user returns to app)
- Handles disposal on unmount

### Step 2: Use QueryBuilder anywhere in your widget tree

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Todos')),
      body: QueryBuilder<List<Todo>>(
        queryKey: QueryKey(['todos']),
        queryFn: () => api.fetchTodos(),
        staleTime: Duration(minutes: 5),
        builder: (context, state) {
          if (state.isLoading) return Center(child: CircularProgressIndicator());
          if (state.isError) return Center(child: Text('Error: ${state.error}'));

          return ListView.builder(
            itemCount: state.data!.length,
            itemBuilder: (_, i) => ListTile(title: Text(state.data![i].title)),
          );
        },
      ),
    );
  }
}
```

That's it. Navigate away and back -- cached data shows instantly. Pull to refresh -- background refetch updates the list. Network error -- automatic retry with backoff.

---

## QueryBuilder

The core widget. Wraps a `QueryObserver` and rebuilds when data changes.

```dart
QueryBuilder<T>(
  queryKey: QueryKey(['key']),       // Required: unique cache identifier
  queryFn: () => fetchData(),        // Required: the async function to call
  builder: (context, state) { ... }, // Required: build your UI from state

  // Optional:
  staleTime: Duration(minutes: 5),   // How long data is "fresh" (default: 0)
  gcTime: Duration(minutes: 30),     // How long unused data stays cached (default: 5min)
  enabled: true,                     // Set false to pause fetching
  retryCount: 3,                     // Retry attempts on failure (default: 3)
  placeholderData: [],               // Show while loading
  select: (data) => data.length,     // Transform data before it reaches builder
  refetchInterval: Duration(seconds: 30), // Auto-refetch on interval
)
```

### Understanding the State Object

The `state` parameter in the builder gives you everything:

```dart
builder: (context, state) {
  // Loading states
  state.isLoading    // First load, no data yet -- show spinner
  state.isFetching   // Any network activity (including background refresh)
  state.isRefetching // Has data AND is refetching (background refresh)

  // Data states
  state.isSuccess    // Data available
  state.data         // The actual data (T?)
  state.isPending    // No data yet (before first fetch completes)

  // Error states
  state.isError         // Fetch failed
  state.error           // The error object
  state.isLoadingError  // Error with no data (first load failed)
  state.isRefetchError  // Error but stale data still available

  // Meta
  state.isStale          // Past staleTime
  state.isPlaceholderData // Showing placeholder, not real data
  state.isFetched        // At least one fetch completed
  state.dataUpdatedAt    // When data was last updated
}
```

### Common Builder Patterns

**Simple loading/error/data:**
```dart
builder: (context, state) {
  if (state.isLoading) return CircularProgressIndicator();
  if (state.isError) return Text('Error: ${state.error}');
  return DataWidget(data: state.data!);
}
```

**Show stale data during refetch:**
```dart
builder: (context, state) {
  if (state.isLoading) return CircularProgressIndicator();

  return Column(
    children: [
      if (state.isFetching) LinearProgressIndicator(), // subtle refresh indicator
      DataWidget(data: state.data!),
      if (state.isRefetchError)
        Text('Failed to refresh, showing cached data'),
    ],
  );
}
```

**Pull to refresh:**
```dart
builder: (context, state) {
  if (state.isLoading) return CircularProgressIndicator();

  return RefreshIndicator(
    onRefresh: () async {
      DartQuery.of(context).invalidateQueries(queryKey: QueryKey(['todos']));
    },
    child: ListView(...),
  );
}
```

---

## MutationBuilder

For **creating, updating, or deleting** data. Gives you a `mutate` function and tracks the mutation state.

```dart
MutationBuilder<Todo, CreateTodoInput>(
  mutationFn: (input) => api.createTodo(input),
  onSuccess: (data, input, context) async {
    // Invalidate related queries after successful mutation
    DartQuery.of(context).invalidateQueries(queryKey: QueryKey(['todos']));
  },
  builder: (context, state, mutate, mutateAsync) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: state.isPending
              ? null  // Disable while in progress
              : () => mutate(CreateTodoInput(title: 'New todo')),
          child: Text(state.isPending ? 'Saving...' : 'Add Todo'),
        ),
        if (state.isError) Text('Failed: ${state.error}', style: TextStyle(color: Colors.red)),
        if (state.isSuccess) Text('Created: ${state.data!.title}', style: TextStyle(color: Colors.green)),
      ],
    );
  },
)
```

**`mutate` vs `mutateAsync`:**
- `mutate(input)` -- Fire and forget. Errors are handled via `onError` callback.
- `mutateAsync(input)` -- Returns a `Future`. You can `await` it and handle errors with try/catch.

---

## InfiniteQueryBuilder

For **paginated lists** and **infinite scroll**. Manages page params and exposes `fetchNextPage` / `fetchPreviousPage`.

```dart
InfiniteQueryBuilder<List<Todo>, int>(
  queryKey: QueryKey(['todos', 'infinite']),
  queryFn: (pageParam) => api.fetchTodos(page: pageParam),
  initialPageParam: 1,
  getNextPageParam: (lastPage, allPages, lastParam, allParams) {
    // Return null when there are no more pages
    return lastPage.length == 20 ? lastParam + 1 : null;
  },
  builder: (context, state, fetchNextPage, fetchPreviousPage) {
    if (state.isLoading) return Center(child: CircularProgressIndicator());

    final allItems = state.data?.pages.expand((page) => page).toList() ?? [];

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        // Auto-fetch next page when near bottom
        if (scrollInfo.metrics.extentAfter < 200) {
          fetchNextPage();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: allItems.length,
        itemBuilder: (_, i) => ListTile(title: Text(allItems[i].title)),
      ),
    );
  },
)
```

**Cursor-based pagination:**
```dart
InfiniteQueryBuilder<List<Post>, String>(
  queryKey: QueryKey(['posts']),
  queryFn: (cursor) => api.fetchPosts(cursor: cursor),
  initialPageParam: '',
  getNextPageParam: (lastPage, allPages, lastCursor, allCursors) {
    return lastPage.isNotEmpty ? lastPage.last.cursor : null;
  },
  builder: (context, state, fetchNextPage, _) { ... },
)
```

---

## QueriesBuilder

Fetch **multiple queries in parallel** with a single widget:

```dart
QueriesBuilder(
  queries: [
    QueryConfig(key: QueryKey(['user']), fn: () => api.fetchUser()),
    QueryConfig(key: QueryKey(['todos']), fn: () => api.fetchTodos()),
    QueryConfig(key: QueryKey(['settings']), fn: () => api.fetchSettings()),
  ],
  builder: (context, results) {
    final userState = results[0];
    final todosState = results[1];
    final settingsState = results[2];

    if (results.any((r) => r.isLoading)) {
      return CircularProgressIndicator();
    }

    return Dashboard(
      user: userState.data,
      todos: todosState.data,
      settings: settingsState.data,
    );
  },
)
```

---

## Common Patterns

### Access the Client Anywhere

```dart
final client = DartQuery.of(context);

// Invalidate queries (triggers refetch)
client.invalidateQueries(queryKey: QueryKey(['todos']));

// Update cached data directly
client.setQueryData<User>(QueryKey(['user']), updatedUser);

// Prefetch data for the next screen
client.prefetchQuery(queryKey: QueryKey(['todo', id]), queryFn: () => api.fetchTodo(id));
```

### Conditional Fetching

```dart
QueryBuilder<UserProfile>(
  queryKey: QueryKey(['profile', userId]),
  queryFn: () => api.fetchProfile(userId!),
  enabled: userId != null, // Won't fetch until userId is set
  builder: (context, state) { ... },
)
```

### Refetch Interval (Polling)

```dart
QueryBuilder<StockPrice>(
  queryKey: QueryKey(['stock', ticker]),
  queryFn: () => api.fetchPrice(ticker),
  refetchInterval: Duration(seconds: 5), // Auto-refetch every 5 seconds
  builder: (context, state) {
    return Text('\$${state.data?.price ?? '---'}');
  },
)
```

---

## API Reference

### DartQueryProvider

| Property | Type | Description |
|---|---|---|
| `client` | `QueryClient` | Required. The query client instance. |
| `child` | `Widget` | Required. Your app widget tree. |

### DartQuery.of(context)

Returns the `QueryClient` from the nearest `DartQueryProvider`. Throws if no provider found.

### QueryBuilder<T>

| Property | Type | Default | Description |
|---|---|---|---|
| `queryKey` | `QueryKey` | Required | Cache key |
| `queryFn` | `Future<T> Function()` | Required | Fetch function |
| `builder` | `Widget Function(context, state)` | Required | Build UI from state |
| `staleTime` | `Duration` | `Duration.zero` | Freshness window |
| `gcTime` | `Duration` | `5 minutes` | Cache retention after unmount |
| `enabled` | `bool` | `true` | Enable/disable fetching |
| `retryCount` | `int` | `3` | Retry attempts |
| `placeholderData` | `T?` | `null` | Show while loading |
| `select` | `T Function(T)?` | `null` | Transform data |
| `refetchInterval` | `Duration?` | `null` | Auto-refetch interval |

---

## DevTools

Add visual cache inspection to your app:

```dart
DartQueryProvider(
  client: queryClient,
  child: DartQueryDevtools(
    enabled: kDebugMode,
    child: MaterialApp(...),
  ),
);
```

See [`tanquery_devtools`](https://pub.dev/packages/tanquery_devtools) for details.

---

## License

MIT
