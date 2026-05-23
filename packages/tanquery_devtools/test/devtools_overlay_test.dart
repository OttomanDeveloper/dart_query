import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanquery/tanquery.dart' show QueryClient, QueryKey;
import 'package:tanquery_flutter/tanquery_flutter.dart';
import 'package:tanquery_devtools/tanquery_devtools.dart';

void main() {
  testWidgets('DartQueryDevtools shows FAB when enabled', (tester) async {
    final client = QueryClient();

    await tester.pumpWidget(
      MaterialApp(
        home: DartQueryProvider(
          client: client,
          child: DartQueryDevtools(
            enabled: true,
            child: const Scaffold(body: Text('App')),
          ),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('App'), findsOneWidget);
  });

  testWidgets('DartQueryDevtools hidden when disabled', (tester) async {
    final client = QueryClient();

    await tester.pumpWidget(
      MaterialApp(
        home: DartQueryProvider(
          client: client,
          child: DartQueryDevtools(
            enabled: false,
            child: const Scaffold(body: Text('App')),
          ),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('App'), findsOneWidget);
  });

  testWidgets('FAB toggles panel open/close', (tester) async {
    final client = QueryClient();
    final cache = client.getQueryCache();
    cache.build<String>(
      queryKey: QueryKey(['test']),
      queryFn: () async => '',
      initialData: 'hello',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DartQueryProvider(
          client: client,
          child: DartQueryDevtools(
            child: const Scaffold(body: Text('App')),
          ),
        ),
      ),
    );

    // Panel not visible initially
    expect(find.text('Queries (1)'), findsNothing);

    // Tap FAB to open
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.text('Queries (1)'), findsOneWidget);

    // Tap FAB again to close
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.text('Queries (1)'), findsNothing);

    client.clear();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('Panel shows query list with data', (tester) async {
    final client = QueryClient();
    final cache = client.getQueryCache();
    cache.build<String>(
      queryKey: QueryKey(['todos']),
      queryFn: () async => '',
      initialData: 'data',
    );
    cache.build<String>(
      queryKey: QueryKey(['users']),
      queryFn: () async => '',
      initialData: 'data',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DartQueryProvider(
          client: client,
          child: DartQueryDevtools(
            child: const Scaffold(body: Text('App')),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.text('Queries (2)'), findsOneWidget);
    expect(find.text('todos'), findsOneWidget);
    expect(find.text('users'), findsOneWidget);

    client.clear();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 6));
  });
}
