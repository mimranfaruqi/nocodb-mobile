import 'package:collection/collection.dart';
import 'package:nocodb/common/extensions.dart';
import 'package:nocodb/common/logger.dart';import 'package:nocodb/features/core/providers/filter_provider.dart';import 'package:nocodb/features/core/providers/utils.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/models.dart';
import 'package:nocodb/nocodb_sdk/symbols.dart';
import 'package:riverpod/legacy.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

final workspaceProvider = StateProvider<NcWorkspace?>((ref) => null);
final projectProvider = StateProvider<NcProject?>((ref) => null);
final tableProvider = StateProvider<NcTable?>((ref) => null);

final tablesProvider = StateProvider<NcTables?>((ref) => null);

final isLoadedProvider = Provider<bool>((ref) {
  final table = ref.watch(tableProvider);
  final view = ref.watch(viewProvider);
  final tables = ref.watch(tablesProvider);
  return table != null &&
      view != null &&
      view.fkModelId == table.id &&
      tables != null;
});

Future<Map<String, NcTable>> getRelations(NcTable table) async {
  final relations = <String, NcTable>{};

  await Future.wait(
    table.foreignKeys.map((fk) async {
      await serialize(
        await api.dbTableRead(tableId: fk),
        fn: (result) {
          logger.info('fetched relation. ${table.title}->${result.title}');
          relations[fk] = result;
        },
      );
    }),
  );
  return relations;
}

@Riverpod(keepAlive: true)
class View extends _$View {
  @override
  NcView? build() => null;

  void showSystemFields() async {
    if (state == null) {
      return;
    }
    serialize(
      await api.dbViewUpdate(
        viewId: state!.id,
        data: {'show_system_fields': !state!.showSystemFields},
      ),
      fn: (ok) => state = ok,
    );
  }

  void set(NcView view) => state = view;
}

@riverpod
Future<NcWorkspaceList> workspaceList(Ref ref) async => serialize(
  await api.workspaceList(),
  fn: (ok) {
    if (ref.read(workspaceProvider) == null) {
      ref.read(workspaceProvider.notifier).state = ok.list.firstOrNull;
    }
    return ok;
  },
);

@riverpod
Future<NcProjectList> baseList(Ref ref, String workspaceId) async =>
    unwrap(await api.baseList(workspaceId));

@riverpod
Future<NcProjectList> projectList(Ref ref) async =>
    unwrap(await api.projectList());

@Riverpod(keepAlive: true)
Future<NcSimpleTableList> tableList(Ref ref, String projectId) async =>
    unwrap(await api.dbTableList(projectId: projectId));

@Riverpod(keepAlive: true)
Future<ViewList> viewList(Ref ref, String tableId) async =>
    unwrap(await api.dbViewList(tableId: tableId));

@Riverpod(keepAlive: true)
Future<List<NcViewColumn>> viewColumnList(Ref ref, String viewId) async =>
    unwrap(await api.dbViewColumnList(viewId: viewId));

@Riverpod()
class Fields extends _$Fields {
  static const debug = false;

  @override
  Future<List<NcTableColumn>> build(NcView view) async {
    final table = ref.watch(tableProvider);
    if (table == null) {
      return [];
    }

    return ref.watch(viewColumnListProvider(view.id).future).then((
      viewColumns,
    ) {
      final fields = viewColumns.getColumnsToShow(table, view)
        ..sort((a, b) => a.order.compareTo(b.order));
      return fields
          .map((columns) => columns.toTableColumn(table.columns))
          .whereNotNull()
          .toList();
    });
  }
}

class SearchQuery {
  const SearchQuery({
    required this.columnName,
    required this.operator,
    required this.query,
  });
  final String columnName;
  final String query;
  final QueryOperator operator;

  @override
  String toString() => '($columnName,$operator,$query)';
}

final searchQueryFamily = StateProviderFamily<SearchQuery?, NcView>(
  (ref, view) => null,
);

@riverpod
class DataRows extends _$DataRows {
  late String? _pkName;

  Future<NcRowList> _fetchRowsWithFallback({
    required NcView view,
    required NcTable table,
    required Map<String, NcTable> relations,
    SearchQuery? where,
    int? offset,
    int? limit,
  }) async {
    try {
      return await serialize(
        await api.dbViewRowList(
          view: view,
          where: where,
          offset: offset,
          limit: limit,
        ),
        fn: (result) => populate(result, table, relations),
      );
    } catch (e, s) {
      if (where == null) {
        rethrow;
      }
      logger.warning('Row fetch with user filter failed; retrying without filter: $e');
      logger.fine(s.toString());
      return await serialize(
        await api.dbViewRowList(
          view: view,
          offset: offset,
          limit: limit,
        ),
        fn: (result) => populate(result, table, relations),
      );
    }
  }

  dynamic _getForeignKeyPrimaryValue({
    required Map<String, dynamic> row,
    required String columnId,
    required NcTable table,
    required Map<String, NcTable> relations,
  }) {
    final parentColumn = table.getParentColumn(columnId);
    if (parentColumn == null) {
      return;
    }

    final pkTitle = relations[parentColumn.fkRelatedModelId!]!.pkNames.first;

    final value = row[parentColumn.title];
    return value is Map ? value[pkTitle] : null;
  }

  NcRowList populate(
    NcRowList rowList,
    NcTable table,
    Map<String, NcTable> relations,
  ) {
    final columns = rowList.toTableColumns(table.columns);
    return rowList.copyWith(
      list: rowList.list
          .map(
            (row) => {
              // Use columns instead of table.columns.
              // table.columns contain unnecessary ones.
              for (final column in columns)
                column.title: column.uidt != UITypes.foreignKey
                    ? row[column.title]
                    : _getForeignKeyPrimaryValue(
                        columnId: column.id,
                        row: row,
                        table: table,
                        relations: relations,
                      ),
            },
          )
          .toList(),
    );
  }

  @override
  Future<NcRowList?> build() async {
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return null;
    }
    final table = ref.watch(tableProvider)!;
    final tables = ref.watch(tablesProvider)!;
    final view = ref.watch(viewProvider)!;
    final globalFilter = ref.watch(globalFilterProvider);

    // This provider should be updated every time sort is updated.
    // final _ = ref.watch(sortListProvider(view.id));

    _pkName = table.pkName;
    final searchQuery = ref.watch(searchQueryFamily(view));
    
    // Apply filters from global filter state only if table exposes a user name column (strict: "user")
    SearchQuery? finalQuery = searchQuery;
    const nameCandidates = ['user'];

    final userColumn = table.columns.firstWhereOrNull((c) {
      final name = c.columnName?.toLowerCase();
      final title = c.title.toLowerCase();
      return nameCandidates.contains(name) || nameCandidates.contains(title);
    });

    if (userColumn != null && globalFilter.userId != null && globalFilter.userId!.isNotEmpty) {
      final columnName = userColumn.columnName?.isNotEmpty == true
          ? userColumn.columnName!
          : userColumn.title;
      logger.info('Applying user filter for user name: ${globalFilter.userId} on table ${table.title} column $columnName');
      finalQuery = SearchQuery(
        columnName: columnName,
        operator: QueryOperator.eq,
        query: globalFilter.userId!,
      );
      logger.info('Filter query: $finalQuery');
    } else {
      if (userColumn == null) {
        logger.info('Table ${table.title} has no user name column; skipping user filter');
      } else {
        logger.info('No user filter applied. globalFilter.userId: ${globalFilter.userId}');
      }
    }

    return _fetchRowsWithFallback(
      view: view,
      table: table,
      relations: tables.relationMap,
      where: finalQuery,
    );
  }

  Future<void> loadNextPage() async {
    final isLoaded = ref.read(isLoadedProvider);
    if (!isLoaded) {
      return;
    }

    final tables = ref.read(tablesProvider)!;
    final view = ref.read(viewProvider)!;
    final globalFilter = ref.read(globalFilterProvider);
    final value = state.value;
    if (value == null) {
      assert(false);
      logger.warning('state.value is null');
      return;
    }
    final currentRows = value.list;
    final pageInfo = value.pageInfo!;

    final searchQuery = ref.read(searchQueryFamily(view));
    
    // Apply filters from global filter state (same as build method, strict: "user" column only)
    SearchQuery? finalQuery = searchQuery;
    const nameCandidates = ['user'];

    final userColumn = tables.table.columns.firstWhereOrNull((c) {
      final name = c.columnName?.toLowerCase();
      final title = c.title.toLowerCase();
      return nameCandidates.contains(name) || nameCandidates.contains(title);
    });

    if (userColumn != null && globalFilter.userId != null && globalFilter.userId!.isNotEmpty) {
      final columnName = userColumn.columnName?.isNotEmpty == true
          ? userColumn.columnName!
          : userColumn.title;
      final userFilter = SearchQuery(
        columnName: columnName,
        operator: QueryOperator.eq,
        query: globalFilter.userId!,
      );
      finalQuery = userFilter;
    }

    final result = await _fetchRowsWithFallback(
      view: view,
      table: tables.table,
      relations: tables.relationMap,
      where: finalQuery,
      offset: pageInfo.page * pageInfo.pageSize,
      limit: pageInfo.pageSize,
    );

    state = AsyncData(
      NcRowList(
        list: [...currentRows, ...result.list],
        pageInfo: result.pageInfo,
      ),
    );
  }

  Future<void> deleteRow({required String rowId}) async {
    state = const AsyncValue.loading();
    final view = ref.read(viewProvider)!;
    await api.dbViewRowDelete(view: view, rowId: rowId);

    final currentRows = state.value?.list;

    if (currentRows == null) {
      logger.warning('currentRows are null');
      return;
    }
    if (_pkName == null) {
      return;
    }

    final newRows = currentRows
        .whereNot((row) => row[_pkName].toString() == rowId)
        .toList();

    state = AsyncData(
      NcRowList(list: newRows, pageInfo: state.value?.pageInfo),
    );
  }

  Future<NcRow> updateRow({
    required String rowId,
    required Map<String, dynamic> data,
  }) async {
    // The result doesn't contain related fields.
    final view = ref.read(viewProvider)!;
    final result = await api.dbViewRowUpdate(
      view: view,
      rowId: rowId,
      data: data,
    );
    logger.info(result);

    return serialize(
      await api.dbViewRowUpdate(view: view, rowId: rowId, data: data),
      fn: (result) {
        final updatedFields = data.keys.where(
          (field) => result.keys.contains(field),
        );

        final currentRows = state.value?.list;

        if (currentRows == null) {
          logger.warning('currentRows is null');
          return {};
        }

        Map<String, dynamic> newRow = {};
        final newRows = currentRows.map<Map<String, dynamic>>((row) {
          if (row[_pkName].toString() != rowId) {
            return row;
          }

          for (final updatedField in updatedFields) {
            row.update(updatedField, (_) => result[updatedField]);
          }
          newRow = row;
          return newRow;
        }).toList();

        state = AsyncData(
          NcRowList(list: newRows, pageInfo: state.value?.pageInfo),
        );
        return newRow;
      },
    );
  }

  Future<Map<String, dynamic>> createRow(Map<String, dynamic> row) async {
    final view = ref.read(viewProvider)!;
    return serialize(
      await api.dbViewRowCreate(view: view, data: row),
      fn: (result) {
        state = AsyncData(
          NcRowList(
            list: [...state.value?.list ?? [], result],
            pageInfo: state.value?.pageInfo,
          ),
        );
        return result;
      },
    );
  }

  Map<String, dynamic> getRow(String? rowId) {
    if (rowId == null) {
      return {};
    }

    final table = ref.watch(tableProvider);
    final rows = state.valueOrNull?.list ?? [];
    return rows.firstWhereOrNull((row) => table?.getPkFromRow(row) == rowId) ??
        {};
  }
}

final rowNestedWhereProvider = StateProvider.family<Where?, NcTableColumn>(
  (ref, column) => null,
);

typedef PrimaryRecord = (String key, dynamic value);
typedef PrimaryRecordList = (List<PrimaryRecord> list, NcPageInfo? pageInfo);

@riverpod
class RowNested extends _$RowNested {
  List<PrimaryRecord> _populate(List<Map<String, dynamic>> list) => list
      .map((row) {
        final key = relation.getRefRowIdFromRow(column: column, row: row);
        if (key == null) {
          return null;
        }
        final value = relation.getPvFromRow(row);
        return (key, value);
      })
      .whereNotNull()
      .toList();

  @override
  Future<PrimaryRecordList> build(
    String rowId,
    NcTableColumn column,
    NcTable relation, {
    bool excluded = false,
  }) async {
    final fn = excluded
        ? api.dbTableRowNestedChildrenExcludedList
        : api.dbTableRowNestedList;

    if (column.isBelongsTo) {
      assert(
        excluded,
        'excluded flag should be true for relation type belongsTo',
      );
    }
    final where = excluded ? ref.watch(rowNestedWhereProvider(column)) : null;

    return serialize(
      await fn(column: column, rowId: rowId, where: where),
      fn: (result) => (_populate(result.list), result.pageInfo!),
    );
  }

  Future<void> load() async {
    if (state.value == null) {
      return;
    }

    final (List<PrimaryRecord> list, NcPageInfo? pageInfo) = state.value!;
    if (pageInfo == null) {
      assert(false);
      return;
    }
    final offset = pageInfo.page * pageInfo.pageSize;
    final limit = pageInfo.pageSize;

    final where = excluded ? ref.read(rowNestedWhereProvider(column)) : null;

    final fn = excluded
        ? api.dbTableRowNestedChildrenExcludedList
        : api.dbTableRowNestedList;

    if (column.isBelongsTo) {
      assert(
        excluded,
        'excluded flag should be true for relation type belongsTo',
      );
    }

    serialize(
      await fn(
        column: column,
        rowId: rowId,
        offset: offset,
        limit: limit,
        where: where,
      ),
      fn: (result) {
        state = AsyncData((
          [...list, ..._populate(result.list)],
          result.pageInfo,
        ));
      },
    );
  }

  void _invalidate() {
    ref
      ..invalidateSelf()
      ..invalidate(dataRowsProvider)
      ..invalidate(
        rowNestedProvider(rowId, column, relation, excluded: !excluded),
      );
  }

  Future<String> remove({required String refRowId}) async => serialize(
    await api.dbTableRowNestedRemove(
      column: column,
      rowId: rowId,
      refRowId: refRowId,
    ),
    fn: (result) {
      _invalidate();
      return result;
    },
  );

  Future<String> link({required refRowId}) async => serialize(
    await api.dbTableRowNestedAdd(
      column: column,
      rowId: rowId,
      refRowId: refRowId,
    ),
    fn: (result) {
      _invalidate();
      return result;
    },
  );
}
/// Provider to fetch users from the database
/// Assumes there's a "Users" or "nc_user" table in the project
@riverpod
Future<List<Map<String, dynamic>>> usersList(Ref ref) async {
  final project = ref.watch(projectProvider);
  if (project == null) {
    logger.warning('Project is null when fetching users');
    return [];
  }

  try {
    // Get the project's tables
    final tables = await ref.watch(tableListProvider(project.id).future);
    logger.info('Found ${tables.list.length} tables in project');
    
    // Log all table names for debugging
    for (final table in tables.list) {
      logger.info('Table: ${table.title} (id: ${table.id})');
    }
    
    // Find the Users table (common names: "Users", "nc_user", "User")
    final usersTable = tables.list.firstWhereOrNull(
      (table) =>
          table.title.toLowerCase() == 'users' ||
          table.title.toLowerCase() == 'nc_user' ||
          table.title.toLowerCase() == 'user',
    );

    if (usersTable == null) {
      logger.warning('Users table not found. Available tables: ${tables.list.map((t) => t.title).toList()}');
      return [];
    }

    logger.info('Found users table: ${usersTable.title}');

    // Get the first view of the Users table
    final views = await ref.watch(viewListProvider(usersTable.id).future);
    logger.info('Found ${views.list.length} views for users table');
    
    if (views.list.isEmpty) {
      logger.warning('No views found for users table');
      return [];
    }

    logger.info('Using view: ${views.list.first.title}');

    // Fetch rows from the Users table
    final rowsResult = await api.dbViewRowList(view: views.list.first);
    final rows = unwrap(rowsResult) as NcRowList;
    
    logger.info('Fetched ${rows.list.length} user records');
    if (rows.list.isNotEmpty) {
      logger.info('First user record keys: ${rows.list.first.keys.toList()}');
      logger.info('First user record: ${rows.list.first}');
    }
    
    return rows.list;
  } catch (e, s) {
    logger.warning('Error fetching users: $e');
    logger.warning(s);
    return [];
  }
}