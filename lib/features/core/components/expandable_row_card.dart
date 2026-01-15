import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

class ExpandableRowCard extends HookConsumerWidget {
  const ExpandableRowCard({
    super.key,
    required this.row,
    required this.columns,
    required this.table,
    required this.onTap,
  });

  final Map<String, dynamic> row;
  final List<NcTableColumn> columns;
  final NcTable table;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = useState(false);

    if (columns.isEmpty) {
      return const SizedBox();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          isExpanded.value = !isExpanded.value;
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: isExpanded.value
              ? _buildExpandedForm(context, ref)
              : _buildCollapsedSummary(context),
        ),
      ),
    );
  }

  Widget _buildCollapsedSummary(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.expand_more),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columns.take(2).map((column) {
              final value = row[column.title];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${column.title}: ${value ?? 'N/A'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedForm(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.expand_less),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const ListTile(title: Text('Edit')),
                  onTap: () {
                    // TODO: Navigate to row editor
                  },
                ),
                PopupMenuItem(
                  child: const ListTile(title: Text('Delete')),
                  onTap: () async {
                    // TODO: Delete row
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...columns.map((column) {
          final value = row[column.title];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value?.toString() ?? 'N/A',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
