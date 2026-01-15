import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nocodb/directus_sdk/directus.dart';
import 'package:nocodb/directus_sdk/models.dart';

part 'directus_providers.g.dart';

// Collections provider (equivalent to tables in NocoDB)
@riverpod
Future<List<DirectusCollection>> collectionList(ref) async {
  final collections = await directus.getCollections();
  // Filter out system collections (starting with directus_)
  return collections.where((c) => !c.collection.startsWith('directus_')).toList();
}

// Selected collection state
@riverpod
class SelectedCollection extends _$SelectedCollection {
  @override
  DirectusCollection? build() => null;

  void select(DirectusCollection collection) {
    state = collection;
  }

  void clear() {
    state = null;
  }
}

// Fields provider for a collection
@riverpod
Future<List<DirectusField>> collectionFields(
  ref,
  String collection,
) async {
  return await directus.getFields(collection);
}

// Items provider (equivalent to rows in NocoDB)
@riverpod
class CollectionItems extends _$CollectionItems {
  int _currentPage = 0;
  static const int _pageSize = 25;
  List<Map<String, dynamic>> _allItems = [];
  bool _hasMore = true;

  @override
  Future<List<Map<String, dynamic>>> build(String collection) async {
    _currentPage = 0;
    _allItems = [];
    _hasMore = true;
    return await _fetchItems();
  }

  Future<List<Map<String, dynamic>>> _fetchItems() async {
    if (!_hasMore) return _allItems;

    final response = await directus.getItems(
      collection,
      limit: _pageSize,
      offset: _currentPage * _pageSize,
    );

    final items = response.data.cast<Map<String, dynamic>>();
    _allItems.addAll(items);
    _hasMore = items.length == _pageSize;

    return _allItems;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    _currentPage++;
    state = AsyncData(await _fetchItems());
  }

  Future<void> refresh() async {
    _currentPage = 0;
    _allItems = [];
    _hasMore = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => await _fetchItems());
  }

  Future<void> createItem(Map<String, dynamic> data) async {
    await directus.createItem(collection, data);
    await refresh();
  }

  Future<void> updateItem(String id, Map<String, dynamic> data) async {
    await directus.updateItem(collection, id, data);
    await refresh();
  }

  Future<void> deleteItem(String id) async {
    await directus.deleteItem(collection, id);
    await refresh();
  }
}

// Search query state
@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String? build() => null;

  void update(String? query) {
    state = query;
  }
}

// Filtered items provider
@riverpod
Future<List<Map<String, dynamic>>> filteredItems(
  ref,
  String collection,
) async {
  final items = await ref.watch(collectionItemsProvider(collection).future);
  final searchQuery = ref.watch(searchQueryProvider);

  if (searchQuery == null || searchQuery.isEmpty) {
    return items;
  }

  // Simple client-side search across all fields
  return items.where((item) {
    return item.values.any((value) {
      if (value == null) return false;
      return value.toString().toLowerCase().contains(searchQuery.toLowerCase());
    });
  }).toList();
}

// Current user provider
@riverpod
Future<DirectusUser> currentUser(ref) async {
  return await directus.getCurrentUser();
}
