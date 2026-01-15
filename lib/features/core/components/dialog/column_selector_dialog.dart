import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/features/core/providers/view_columns_provider.dart';
import 'package:nocodb/nocodb_sdk/models.dart';

class ColumnSelector extends HookConsumerWidget {
  const ColumnSelector({
    super.key,
    required this.view,
    required this.columns,
  });
  final NcView view;
  final List<NcTableColumn> columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColumnsAsync = ref.watch(selectedViewColumnsProvider(view.id));

    return selectedColumnsAsync.when(
      data: (selectedIds) => _buildDialog(context, ref, selectedIds),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> selectedIds,
  ) => AlertDialog(
      title: const Text('Select Columns'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: columns.map((column) {
            final isSelected = selectedIds.contains(column.id);
            return CheckboxListTile(
              title: Text(column.title),
              value: isSelected,
              onChanged: (_) async {
                await ref
                    .read(selectedViewColumnsProvider(view.id).notifier)
                    .toggleColumn(view.id, column.id);
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
}
