# tanquery

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Dart 3](https://img.shields.io/badge/Dart-3.5+-0175C2.svg)](https://dart.dev)

**TanStack Query for Dart/Flutter.** Stop writing fetch-cache-retry-loading-error boilerplate. Get automatic caching, stale-while-revalidate, background refetching, mutations with optimistic updates, infinite queries, and visual devtools.

## Packages

| Package | Description | Version |
|---|---|---|
| [tanquery](packages/tanquery/) | Pure Dart core -- zero Flutter dependency | [![pub](https://img.shields.io/pub/v/tanquery.svg)](https://pub.dev/packages/tanquery) |
| [tanquery_flutter](packages/tanquery_flutter/) | Flutter widget builders | [![pub](https://img.shields.io/pub/v/tanquery_flutter.svg)](https://pub.dev/packages/tanquery_flutter) |
| [tanquery_devtools](packages/tanquery_devtools/) | Visual cache inspector overlay | [![pub](https://img.shields.io/pub/v/tanquery_devtools.svg)](https://pub.dev/packages/tanquery_devtools) |

## Before & After

**Before (every screen):**
```dart
class _TodoScreenState extends State<TodoScreen> {
  bool _isLoading = true;
  Object? _error;
  List<Todo>? _data;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; });
    try {
      _data = await api.fetchTodos();
    } catch (e) { _error = e; }
    setState(() { _isLoading = false; });
  }

  @override Widget build(BuildContext context) {
    if (_isLoading) return CircularProgressIndicator();
    if (_error != null) return Text('Error');
    return ListView(children: _data!.map(TodoTile.new).toList());
  }
}
```

**After:**
```dart
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

Plus you get: caching, retries, background refetch on focus, request deduplication, hierarchical invalidation, and garbage collection. Automatically.

## Quick Start

```dart
import 'package:tanquery_flutter/tanquery_flutter.dart';

void main() => runApp(
  DartQueryProvider(
    client: QueryClient(),
    child: MaterialApp(home: HomeScreen()),
  ),
);
```

## What You Get

- **Automatic caching** -- fetched data is cached and reused
- **Stale-while-revalidate** -- show cached data while silently refetching
- **Background refetch** -- on app focus, network reconnect, configurable intervals
- **Exponential retry** -- 1s, 2s, 4s, 8s, 16s, 30s (configurable)
- **Request deduplication** -- 10 widgets requesting the same data = 1 network call
- **Hierarchical invalidation** -- invalidate `['todos']` clears `['todos', 1]` too
- **Mutations** -- create/update/delete with optimistic updates and rollback
- **Infinite scroll** -- built-in pagination with `fetchNextPage`
- **Streaming** -- WebSocket, SSE, LLM streaming support
- **Cache persistence** -- save/restore cache across app restarts
- **Visual devtools** -- inspect cache state in a floating overlay

## Architecture

Built by analyzing all 8,698 lines of [TanStack Query](https://tanstack.com/query) source code line by line. Faithful Dart port of the proven architecture used by millions of developers.

## License

MIT
