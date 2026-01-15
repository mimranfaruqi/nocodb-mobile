import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/routes.dart';

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

  Widget _buildCollapsedSummary(BuildContext context) => Row(
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

  Widget _buildExpandedForm(BuildContext context, WidgetRef ref) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.expand_less),
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'edit') {
                  final pkValue = table.getPkFromRow(row).toString();
                  await RowEditorRoute(id: pkValue).push(context);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(context, ref);
                }
              },
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

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Row'),
        content: const Text(
          'Are you sure you want to delete this row? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRow(context, ref);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRow(BuildContext context, WidgetRef ref) async {
    try {
      final pkValue = table.getPkFromRow(row).toString();
      await ref.read(dataRowsProvider.notifier).deleteRow(rowId: pkValue);
      if (context.mounted) {
        notifySuccess(context, message: 'Row deleted successfully');
      }
    } catch (e, s) {
      logger.shout(e);
      logger.fine(s.toString());
      if (context.mounted) {
        notifyError(context, e, s);
      }
    }
  }
}
