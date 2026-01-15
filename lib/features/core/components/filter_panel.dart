import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/features/core/providers/filter_provider.dart';
import 'package:nocodb/features/core/providers/providers.dart';

class FilterPanel extends HookConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalFilter = ref.watch(globalFilterProvider);
    final usersAsync = ref.watch(usersListProvider);
    final selectedUserId = useState<String?>(null);

    // Initialize with current filter value
    useEffect(() {
      selectedUserId.value = globalFilter.userId;
      return null;
    }, [globalFilter.userId]);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // User Filter
            const Text(
              'Filter by User',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            usersAsync.when(
              data: (users) {
                // Build dropdown items with users
                final dropdownItems = <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('All Users'),
                  ),
                  ...users.map((user) {
                    // Use name as both display and filter value
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

                return DropdownButton<String>(
                  value: selectedUserId.value ?? '',
                  isExpanded: true,
                  items: dropdownItems,
                  onChanged: (value) {
                    selectedUserId.value = value;
                  },
                  hint: const Text('Select a user...'),
                );
              },
              loading: () => const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Text('Error: $error'),
            ),
            const SizedBox(height: 24),

            // Apply Filter Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final userId = selectedUserId.value;
                  ref.read(globalFilterProvider.notifier).setUserId(
                    userId == '' ? null : userId,
                  );
                  ref.invalidate(dataRowsProvider);
                  await ref.read(dataRowsProvider.future);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        userId == '' || userId == null
                            ? 'Showing all users'
                            : 'Filtered by user: $userId',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Apply Filter'),
              ),
            ),
            const SizedBox(height: 12),

            // Clear Filters Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  selectedUserId.value = '';
                  ref.read(globalFilterProvider.notifier).clearFilters();
                  ref.invalidate(dataRowsProvider);
                  await ref.read(dataRowsProvider.future);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Filters cleared'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text('Clear Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
