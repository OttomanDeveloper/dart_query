import 'package:flutter/material.dart';
import 'package:tanquery/tanquery.dart';

class MutationLogView extends StatelessWidget {
  final List<Mutation> mutations;

  const MutationLogView({super.key, required this.mutations});

  @override
  Widget build(BuildContext context) {
    if (mutations.isEmpty) {
      return const Center(
        child: Text('No mutations', style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return ListView.builder(
      itemCount: mutations.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final mutation = mutations[mutations.length - 1 - index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor(mutation.state.status),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '#${mutation.mutationId}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                mutation.state.status.name,
                style: TextStyle(fontSize: 11, color: _statusColor(mutation.state.status)),
              ),
              const Spacer(),
              if (mutation.scope != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    mutation.scope!.id,
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ),
              if (mutation.state.submittedAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  _formatTime(mutation.state.submittedAt!),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(MutationStatus status) {
    switch (status) {
      case MutationStatus.idle:
        return Colors.grey;
      case MutationStatus.pending:
        return Colors.blue;
      case MutationStatus.success:
        return Colors.green;
      case MutationStatus.error:
        return Colors.red;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
