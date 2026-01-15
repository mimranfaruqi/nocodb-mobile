import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:nocodb/common/extensions.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/components/dialog/column_selector_dialog.dart';
import 'package:nocodb/features/core/components/expandable_row_card.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/features/core/providers/view_columns_provider.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;

class Grid extends HookConsumerWidget {
  const Grid({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horizontalController = useScrollController();
    final verticalController = useScrollController();
    final isLoaded = ref.watch(isLoadedProvider);
    if (!isLoaded) {
      return const CircularProgressIndicator();
    }

    final tables = ref.watch(tablesProvider)!;
    final view = ref.watch(viewProvider)!;

    final columns = ref.watch(fieldsProvider(view)).valueOrNull?.toList() ?? [];
    final selectedColumnsAsync =
        ref.watch(selectedViewColumnsProvider(view.id));

    logger
      ..info('view: ${view.title} has ${columns.length} columns(s).')
      ..info('columns: ${columns.map((e) => e.title).toList()}');

    final dataRow = ref.watch(dataRowsProvider).valueOrNull;
    logger.info('pageInfo: ${dataRow?.pageInfo}');
    final rows = dataRow?.list ?? [];

    return selectedColumnsAsync.when(
      data: (selectedIds) => _buildView(
        context,
        ref,
        rows,
        columns,
        selectedIds,
        tables,
        view,
        verticalController,
        horizontalController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildView(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> rows,
    List<model.NcTableColumn> allColumns,
    List<String> selectedColumnIds,
    model.NcTables tables,
    model.NcView view,
    ScrollController verticalController,
    ScrollController horizontalController,
  ) {
    // Filter columns to only selected ones
    final selectedColumns = selectedColumnIds.isEmpty
        ? allColumns
        : allColumns
            .where((c) => selectedColumnIds.contains(c.id))
            .toList();

    if (allColumns.isEmpty) {
      return _buildRefreshableContent(
        context,
        ref,
        const Center(child: Text('No columns.')),
        verticalController,
      );
    }

    if (rows.isEmpty) {
      return _buildRefreshableContent(
        context,
        ref,
        const Center(child: Text('Empty.')),
        verticalController,
      );
    }

    void handleVerticalScroll() {
      if (verticalController.position.pixels >=
          verticalController.position.maxScrollExtent - 200) {
        // Near end of list, trigger load more
        if (rows.isNotEmpty &&
            ref.read(dataRowsProvider).valueOrNull?.pageInfo?.isLastPage !=
                true) {
          context.loaderOverlay.show();
          ref.read(dataRowsProvider.notifier).loadNextPage().then(
            (_) => Future.delayed(
              const Duration(milliseconds: 500),
              () {
                if (context.mounted) {
                  context.loaderOverlay.hide();
                }
              },
            ),
          ).catchError((e, s) {
            logger.shout(e);
            if (context.mounted) {
              notifyError(context, e, s);
              context.loaderOverlay.hide();
            }
          });
        }
      }
    }

    Future<void> handleRefresh() async {
      try {
        ref.invalidate(dataRowsProvider);
        await ref.read(dataRowsProvider.future);
      } catch (e, s) {
        logger
          ..shout(e)
          ..shout(s);
        if (context.mounted) {
          notifyError(context, e, s);
        }
      }
    }

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            handleVerticalScroll();
          }
          return false;
        },
        child: Stack(
          children: [
            ListView(
              controller: verticalController,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Column selector button
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ColumnSelector(
                          view: view,
                          columns: allColumns,
                        ),
                      );
                    },
                    icon: const Icon(Icons.view_column),
                    label: const Text('Select Columns'),
                  ),
                ),
                // Expandable rows
                ...rows.map((row) => ExpandableRowCard(
                    row: row,
                    columns: selectedColumns,
                    table: tables.table,
                    onTap: () {},
                  )),
                const SizedBox(height: 100),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildRefreshableContent(
    BuildContext context,
    WidgetRef ref,
    Widget content,
    ScrollController verticalController,
  ) {
    Future<void> handleRefresh() async {
      try {
        ref.invalidate(dataRowsProvider);
        await ref.read(dataRowsProvider.future);
      } catch (e, s) {
        logger
          ..shout(e)
          ..shout(s);
        if (context.mounted) {
          notifyError(context, e, s);
        }
      }
    }

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: SingleChildScrollView(
        controller: verticalController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.2),
          child: content,
        ),
      ),
    );
  }}
