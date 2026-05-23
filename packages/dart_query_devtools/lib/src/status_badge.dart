import 'package:flutter/material.dart';
import 'package:dart_query/dart_query.dart';

class StatusBadge extends StatelessWidget {
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final bool isStale;
  final bool isActive;

  const StatusBadge({
    super.key,
    required this.status,
    required this.fetchStatus,
    required this.isStale,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String get _label {
    if (fetchStatus == FetchStatus.fetching) return 'fetching';
    if (fetchStatus == FetchStatus.paused) return 'paused';
    if (status == QueryStatus.error) return 'error';
    if (!isActive) return 'inactive';
    if (isStale) return 'stale';
    return 'fresh';
  }

  Color get _color {
    if (fetchStatus == FetchStatus.fetching) return Colors.blue;
    if (fetchStatus == FetchStatus.paused) return Colors.purple;
    if (status == QueryStatus.error) return Colors.red;
    if (!isActive) return Colors.grey;
    if (isStale) return Colors.orange;
    return Colors.green;
  }
}
