import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/features/directus/providers/directus_providers.dart';
import 'package:nocodb/features/directus/routes.dart';

class DirectusItemsPage extends HookConsumerWidget {
  const DirectusItemsPage({
    super.key,
    required this.collection,
  });

  final String collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(collectionItemsProvider(collection));
    final fieldsAsync = ref.watch(collectionFieldsProvider(collection));

    return Scaffold(
      appBar: AppBar(
        title: Text(_formatCollectionName(collection)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: fieldsAsync.when(
        data: (fields) {
          // Get primary key field
          final pkField = fields.firstWhere(
            (f) => f.schema?['is_primary_key'] == true,
            orElse: () => fields.first,
          );

          return itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No items yet'),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          DirectusItemEditorRoute(
                            collection: collection,
                            itemId: null,
                          ).push(context);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Item'),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(collectionItemsProvider(collection).notifier)
                      .refresh();
                },
                child: ListView.builder(
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(collectionItemsProvider(collection).notifier)
                                .loadMore();
                          },
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Load More'),
                        ),
                      );
                    }

                    final item = items[index];
                    final primaryKey = item[pkField.field];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(
                          _getItemTitle(item, fields),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          _getItemSubtitle(item, fields),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit),
                                title: Text('Edit'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'edit') {
                              DirectusItemEditorRoute(
                                collection: collection,
                                itemId: primaryKey?.toString(),
                              ).push(context);
                            } else if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Item'),
                                  content: const Text(
                                    'Are you sure you want to delete this item?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && context.mounted) {
                                try {
                                  await ref
                                      .read(collectionItemsProvider(collection).notifier)
                                      .deleteItem(primaryKey.toString());
                                  if (context.mounted) {
                                    notifySuccess(
                                      context,
                                      message: 'Item deleted successfully',
                                    );
                                  }
                                } catch (e, s) {
                                  if (context.mounted) {
                                    notifyError(context, e, s);
                                  }
                                }
                              }
                            }
                          },
                        ),
                        onTap: () {
                          DirectusItemEditorRoute(
                            collection: collection,
                            itemId: primaryKey?.toString(),
                          ).push(context);
                        },
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              Future.microtask(() {
                if (context.mounted) {
                  notifyError(context, error, stack);
                }
              });
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Failed to load items'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(
                        collectionItemsProvider(collection),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading fields: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          DirectusItemEditorRoute(
            collection: collection,
            itemId: null,
          ).push(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatCollectionName(String collection) {
    return collection
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getItemTitle(Map<String, dynamic> item, List fields) {
    // Try to find a title-like field
    final titleFields = ['title', 'name', 'label', 'id'];
    for (final field in titleFields) {
      if (item.containsKey(field) && item[field] != null) {
        return item[field].toString();
      }
    }
    return 'Item';
  }

  String _getItemSubtitle(Map<String, dynamic> item, List fields) {
    // Show first few non-null values
    final values = item.entries
        .where((e) => e.value != null && e.key != 'id')
        .take(2)
        .map((e) => '${e.key}: ${e.value}')
        .join(' • ');
    return values.isNotEmpty ? values : 'No data';
  }
}
