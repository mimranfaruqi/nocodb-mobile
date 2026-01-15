import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/features/directus/providers/directus_providers.dart';
import 'package:nocodb/features/directus/routes.dart';

class DirectusCollectionsPage extends HookConsumerWidget {
  const DirectusCollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(collectionListProvider),
          ),
        ],
      ),
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return const Center(
              child: Text('No collections found'),
            );
          }

          return ListView.builder(
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return ListTile(
                leading: Icon(
                  _getCollectionIcon(collection.icon),
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(
                  _formatCollectionName(collection.collection),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: collection.note != null
                    ? Text(
                        collection.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ref.read(selectedCollectionProvider.notifier).select(collection);
                  DirectusItemsRoute(collection: collection.collection).go(context);
                },
              );
            },
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
                Text(
                  'Failed to load collections',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(collectionListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getCollectionIcon(String? iconName) {
    if (iconName == null) return Icons.table_chart;
    
    // Map common Directus icon names to Material icons
    switch (iconName) {
      case 'people':
      case 'person':
        return Icons.people;
      case 'article':
      case 'description':
        return Icons.article;
      case 'folder':
        return Icons.folder;
      case 'image':
        return Icons.image;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.table_chart;
    }
  }

  String _formatCollectionName(String collection) {
    // Convert snake_case to Title Case
    return collection
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
