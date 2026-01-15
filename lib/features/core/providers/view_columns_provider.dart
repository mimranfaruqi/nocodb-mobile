import 'dart:convert';

import 'package:nocodb/common/logger.dart';
import 'package:nocodb/common/preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'view_columns_provider.g.dart';

/// Provider to manage selected columns per view
/// Persists to local storage as JSON
@Riverpod(keepAlive: true)
class SelectedViewColumns extends _$SelectedViewColumns {
  static const String _storageKeyPrefix = 'view_columns_';

  Future<List<String>> _loadFromStorage(String viewId) async {
    try {
      final prefs = Preferences();
      await prefs.load();
      final key = '$_storageKeyPrefix$viewId';
      final stored = await prefs.get<String>(key: key);
      if (stored != null) {
        final decoded = List<String>.from(jsonDecode(stored) as List);
        logger.info('Loaded selected columns for view $viewId: $decoded');
        return decoded;
      }
      return [];
    } catch (e, s) {
      logger.warning('Failed to load selected columns: $e');
      logger.fine(s.toString());
      return [];
    }
  }

  Future<void> _saveToStorage(String viewId, List<String> columns) async {
    try {
      final prefs = Preferences();
      await prefs.load();
      final key = '$_storageKeyPrefix$viewId';
      await prefs.set(key: key, value: jsonEncode(columns));
      logger.info('Saved selected columns for view $viewId: $columns');
    } catch (e, s) {
      logger.warning('Failed to save selected columns: $e');
      logger.fine(s.toString());
    }
  }

  @override
  Future<List<String>> build(String viewId) async {
    return await _loadFromStorage(viewId);
  }

  /// Update selected columns and persist
  Future<void> updateColumns(String viewId, List<String> columnIds) async {
    state = AsyncData(columnIds);
    await _saveToStorage(viewId, columnIds);
  }

  /// Toggle a column's selection
  Future<void> toggleColumn(String viewId, String columnId) async {
    final current = state.value ?? [];
    final updated = current.contains(columnId)
        ? current.where((id) => id != columnId).toList()
        : [...current, columnId];
    await updateColumns(viewId, updated);
  }
}
