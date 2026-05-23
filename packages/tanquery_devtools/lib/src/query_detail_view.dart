import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tanquery/tanquery.dart';
import 'status_badge.dart';

class QueryDetailView extends StatelessWidget {
  final Query query;
  final VoidCallback onBack;
  final VoidCallback onInvalidate;
  final VoidCallback onRemove;
  final VoidCallback onRefetch;
  final VoidCallback onReset;

  const QueryDetailView({
    super.key,
    required this.query,
    required this.onBack,
    required this.onInvalidate,
    required this.onRemove,
    required this.onRefetch,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                query.queryKey.parts.join(', '),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const Divider(height: 12),

        // Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              StatusBadge(
                status: query.state.status,
                fetchStatus: query.state.fetchStatus,
                isStale: query.isStaleByTime(Duration.zero),
                isActive: query.isActive(),
              ),
              const SizedBox(width: 8),
              Text('Observers: ${query.observerCount}', style: const TextStyle(fontSize: 11)),
              const Spacer(),
              Text(
                'Updates: ${query.state.dataUpdateCount}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 4,
            children: [
              _ActionChip(label: 'Invalidate', onTap: onInvalidate),
              _ActionChip(label: 'Refetch', onTap: onRefetch),
              _ActionChip(label: 'Reset', onTap: onReset),
              _ActionChip(label: 'Remove', onTap: onRemove, color: Colors.red),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Data
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatData(query.state.data),
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
                if (query.state.error != null) ...[
                  const SizedBox(height: 8),
                  const Text('Error:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  Text(
                    query.state.error.toString(),
                    style: const TextStyle(fontSize: 11, color: Colors.red, fontFamily: 'monospace'),
                  ),
                ],
                const SizedBox(height: 8),
                const Text('State:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _StateRow('status', query.state.status.name),
                _StateRow('fetchStatus', query.state.fetchStatus.name),
                _StateRow('isInvalidated', '${query.state.isInvalidated}'),
                _StateRow('dataUpdateCount', '${query.state.dataUpdateCount}'),
                _StateRow('errorUpdateCount', '${query.state.errorUpdateCount}'),
                _StateRow('failureCount', '${query.state.fetchFailureCount}'),
                if (query.state.dataUpdatedAt != null)
                  _StateRow('dataUpdatedAt', query.state.dataUpdatedAt.toString()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatData(Object? data) {
    if (data == null) return 'null';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionChip({required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color ?? Colors.blue, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, color: color ?? Colors.blue),
        ),
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  final String label;
  final String value;

  const _StateRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
