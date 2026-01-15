import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:nocodb/common/components/scroll_detector.dart';
import 'package:nocodb/common/extensions.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/features/core/components/cell.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/nocodb_sdk/models.dart' as model;
import 'package:nocodb/nocodb_sdk/symbols.dart';

class Grid extends HookConsumerWidget {
  const Grid({
    super.key,
  });

  static const double _dataColumnWidth = 140;
  static const double _blankDataColumnWidth = 140;
  static const _blankDataColumn = DataColumn2(
    label: Text(''),
    fixedWidth: _blankDataColumnWidth,
  );

  static const _blankDataCell = DataCell(SizedBox());

  List<DataCell> _buildDataCellList(
    Map<String, dynamic> row,
    List<model.NcTableColumn> columns,
    model.NcTables tableMeta,
    WidgetRef ref,
    int blankLength,
  ) {
    // TODO: Some child tables don't have a primary key.
    // TODO: Stop changing the type of primary key.
    final context = useContext();

    final pkId = tableMeta.table.getPkFromRow(row).toString();
    final cells = columns.map((column) {
      final value = row[column.title];

      return Cell(
        rowId: pkId,
        column: column,
        value: value,
        context: context,
        ref: ref,
      ).build();
    }).toList();

    return cells
      ..addAll(
        List.generate(blankLength, (index) => _blankDataCell),
      );
  }

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
    logger
      ..info('view: ${view.title} has ${columns.length} columns(s).')
      ..info('columns: ${columns.map((e) => e.title).toList()}');

    final dataRow = ref.watch(dataRowsProvider).valueOrNull;
    logger.info('pageInfo: ${dataRow?.pageInfo}');
    final rows = dataRow?.list ?? [];

    Widget content;

    if (columns.isEmpty) {
      content = const Center(
        child: Text('No columns.'),
      );
    } else if (rows.isEmpty) {
      content = const Center(
        child: Text('Empty.'),
      );
    } else {
      final dataColumns = columns.map((c) { 
        final type = [UITypes.links, UITypes.linkToAnotherRecord]
                .contains(c.uidt)
            ? c.relationType.value
            : c.uidt.value.capitalize();
        return DataColumn2(
          fixedWidth: _dataColumnWidth,
          label: Text(
            '${c.title}\n$type',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList();

      final tableWidth = dataColumns
          .map((c) => c.fixedWidth)
          .whereNotNull()
          .reduce((a, b) => a + b);

      final w = PlatformDispatcher.instance.views.first;
      final size = w.physicalSize / w.devicePixelRatio;
      final screenWidth = size.width;
      final blankLength = tableWidth < screenWidth
          ? ((size.width - tableWidth) ~/ _blankDataColumnWidth) + 1
          : 0;
      logger.fine('tableWidth: $tableWidth, screenWidth: $screenWidth');

      if (0 < blankLength) {
        logger.info(
          'add $blankLength blank column(s) to adjust the spacing.',
        );
      }

      final dataRows = rows.map(
        (row) => DataRow2(
          cells: _buildDataCellList(
            row,
            columns,
            tables,
            ref,
            blankLength,
          ).toList(),
        ),
      );

      dataColumns.addAll(
        List.generate(blankLength, (i) => _blankDataColumn),
      );

      final adjustedMinWidth = dataColumns
          .map((c) => c.fixedWidth)
          .whereNotNull()
          .reduce((a, b) => a + b);

      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalController,
        child: DataTable2(
          checkboxHorizontalMargin: 0,
          columnSpacing: 24,
          horizontalMargin: 24,
          dividerThickness: 1,
          showBottomBorder: true,
          border: TableBorder.all(
            width: 0.1,
          ),
          columns: dataColumns,
          rows: dataRows.toList(),
          // FIXME: Without adjusting minWidth, the following assertion error occurs.
          // ======== Exception caught by widgets library =======================================================
          // The following assertion was thrown building SyncedScrollControllers(dependencies: [ScrollConfiguration, _InheritedTheme, _LocalizationsScope-[GlobalKey#fb890]], state: SyncedScrollControllersState#aa918):
          // DataTable2, combined width of columns of fixed width is greater than availble parent width. Table will be clipped
          // 'package:data_table_2/src/data_table_2.dart':
          // Failed assertion: line 1133 pos 12: 'totalFixedWidth < totalColAvailableWidth'
          //
          // The relevant error-causing widget was:
          // ...
          minWidth: adjustedMinWidth + 50,
        ),
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
        child: ListView(
          controller: verticalController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: content,
            ),
            SizedBox(
              height: 200,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  final position = horizontalController.position;
                  final target = (position.pixels - details.delta.dx)
                      .clamp(position.minScrollExtent, position.maxScrollExtent);
                  horizontalController.jumpTo(target);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
