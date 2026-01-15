import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/features/core/providers/filter_provider.dart';
import 'package:nocodb/features/core/providers/providers.dart';

class FilterPanel extends HookConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalFilter = ref.watch(globalFilterProvider);
    final usersAsync = ref.watch(usersListProvider);

    return usersAsync.when(
      data: (users) {
        final dropdownItems = <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(
            value: '',
            child: Text('All Users'),
          ),
          ...users.map((user) {
            final userName = user['name']?.toString() ??
                user['Name']?.toString() ??
                user['user']?.toString() ??
                'Unknown';
            
            return DropdownMenuItem<String>(
              value: userName,
              child: Text(userName),
            );
          }).toList(),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DropdownButton<String>(
            value: globalFilter.userId ?? '',
            isExpanded: true,
            isDense: true,
            items: dropdownItems,
            onChanged: (value) async {
              ref.read(globalFilterProvider.notifier).setUserId(
                value == '' ? null : value,
              );
              ref.invalidate(dataRowsProvider);
              await ref.read(dataRowsProvider.future);
            },
            hint: const Text('Filter by user'),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Error: $error', style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
