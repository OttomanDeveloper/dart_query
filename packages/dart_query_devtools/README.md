# dart_query_devtools

[![pub package](https://img.shields.io/pub/v/dart_query_devtools.svg)](https://pub.dev/packages/dart_query_devtools)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter 3](https://img.shields.io/badge/Flutter-3.0+-02569B.svg)](https://flutter.dev)

**Visual cache inspector for [dart_query](https://pub.dev/packages/dart_query).** See every cached query, its status, its data, and every mutation -- live, in your running app. One widget, zero configuration.

---

## Why You Need This

When debugging data issues, you need answers to:

- "Is my query fetching or using cached data?"
- "Why is this screen showing stale data?"
- "Did my mutation actually invalidate the right queries?"
- "How many observers are watching this query?"
- "When was this data last updated?"

Without devtools, you add `print()` statements everywhere. With devtools, you tap the FAB and see everything.

---

## Installation

```yaml
dependencies:
  dart_query_devtools: ^0.1.0
```

---

## Setup (30 seconds)

Wrap your app with `DartQueryDevtools` inside `DartQueryProvider`:

```dart
import 'package:flutter/foundation.dart';
import 'package:dart_query_flutter/dart_query_flutter.dart';
import 'package:dart_query_devtools/dart_query_devtools.dart';

void main() {
  runApp(
    DartQueryProvider(
      client: QueryClient(),
      child: DartQueryDevtools(
        enabled: kDebugMode, // Only in debug builds -- zero overhead in release
        child: MaterialApp(home: HomeScreen()),
      ),
    ),
  );
}
```

A purple FAB appears in the bottom-right corner. Tap it to open the inspector panel.

---

## What You See

### Query List Tab

Every cached query at a glance:

```
+------------------------------------------+
| Queries (5)  |  Mutations (2)        [x] |
|------------------------------------------|
| [Filter by key...]                       |
|                                          |
| [fresh]    todos              2m ago  3  |
| [stale]    users              8m ago  1  |
| [fetching] posts              0s ago  2  |
| [error]    analytics         12m ago  0  |
| [inactive] old-data          25m ago  0  |
|                                          |
+------------------------------------------+
```

Each row shows:
- **Status badge** -- Color-coded: green (fresh), orange (stale), blue (fetching), purple (paused), red (error), grey (inactive)
- **Query key** -- The key parts for easy identification
- **Data age** -- How long ago the data was last updated
- **Observer count** -- How many widgets are watching this query

### Query Detail (tap any query)

```
+------------------------------------------+
| < todos                                  |
|------------------------------------------|
| [fresh]  Observers: 3  Updates: 7       |
|                                          |
| [Invalidate] [Refetch] [Reset] [Remove]  |
|                                          |
| Data:                                    |
| [                                        |
|   {"id": 1, "title": "Buy milk"},        |
|   {"id": 2, "title": "Walk dog"}         |
| ]                                        |
|                                          |
| State:                                   |
| status: success                          |
| fetchStatus: idle                        |
| isInvalidated: false                     |
| dataUpdateCount: 7                       |
| dataUpdatedAt: 2026-05-23 14:32:01       |
+------------------------------------------+
```

**Actions you can take:**
- **Invalidate** -- Mark as stale, trigger background refetch
- **Refetch** -- Force a fresh fetch right now
- **Reset** -- Reset to initial state (before any fetches)
- **Remove** -- Delete from cache entirely

### Mutation Log Tab

Chronological log of every mutation:

```
+------------------------------------------+
| Queries (5)  |  Mutations (2)        [x] |
|------------------------------------------|
|                                          |
| * #3  success                  14:32:01  |
| * #2  error    [create-todo]   14:31:45  |
| * #1  success                  14:30:22  |
|                                          |
+------------------------------------------+
```

Shows mutation ID, status (color-coded), scope label, and timestamp.

---

## Status Badge Colors

| Color | Status | Meaning |
|-------|--------|---------|
| Green | `fresh` | Data is within staleTime, no refetch needed |
| Orange | `stale` | Data is past staleTime, will refetch on next access |
| Blue | `fetching` | Network request in progress |
| Purple | `paused` | Would fetch but device is offline/unfocused |
| Red | `error` | Last fetch failed |
| Grey | `inactive` | No widgets are watching this query |

---

## Tips for Debugging

### "Why is my screen showing old data?"

1. Open devtools, find the query
2. Check the status badge -- is it `stale`? `error`?
3. Check `dataUpdatedAt` -- when was it last refreshed?
4. Check observer count -- is your widget actually subscribed?
5. Try tapping **Invalidate** to force a refresh

### "My mutation succeeded but the list didn't update"

1. Open the Mutations tab -- confirm the mutation shows `success`
2. Switch to Queries tab -- is the list query still showing old data?
3. Check if the list query was invalidated (look at `dataUpdateCount`)
4. If not: your `onSuccess` callback probably isn't invalidating the right key

### "I have too many queries in the cache"

1. Open devtools and look at the inactive (grey) queries
2. These are queries with no observers -- they'll be garbage collected after `gcTime`
3. Use the **Remove** action to clean them up immediately
4. Or tap the trash icon in the header to clear everything

---

## Performance

- **Zero overhead when `enabled: false`** -- the widget returns `child` directly, no subscriptions, no listeners
- **Live updates** -- subscribes to both `QueryCache` and `MutationCache` events
- **Debug-only** -- use `kDebugMode` to ensure it's never in release builds

---

## License

MIT
