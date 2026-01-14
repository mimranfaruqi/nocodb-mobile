import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nocodb/features/core/pages/cloud_project_list.dart';
import 'package:nocodb/features/core/pages/link_record.dart';
import 'package:nocodb/features/core/pages/project_list.dart';
import 'package:nocodb/features/core/pages/row_editor.dart';
import 'package:nocodb/features/core/pages/sheet.dart';
import 'package:nocodb/features/core/pages/sheet_selector.dart';
import 'package:nocodb/features/core/utils.dart';
import 'package:nocodb/features/debug/debug.dart';
import 'package:nocodb/features/sign_in/pages/sign_in.dart';

part 'routes.g.dart';

// ✅ HomeRoute - Root route
@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData with _$HomeRoute {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const SignInPage();
}

// ✅ ProjectListRoute - Each route needs its own @TypedGoRoute
@TypedGoRoute<ProjectListRoute>(path: '/project_list')
class ProjectListRoute extends GoRouteData with _$ProjectListRoute {
  const ProjectListRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProjectListPage();
}

// ✅ CloudProjectListRoute
@TypedGoRoute<CloudProjectListRoute>(path: '/cloud_project_list')
class CloudProjectListRoute extends GoRouteData with _$CloudProjectListRoute {
  const CloudProjectListRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const CloudProjectListPage();
}

// ✅ SheetRoute
@TypedGoRoute<SheetRoute>(path: '/sheet')
class SheetRoute extends GoRouteData with _$SheetRoute {
  const SheetRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const SheetPage();
}

// ✅ SheetSelectorRoute
@TypedGoRoute<SheetSelectorRoute>(path: '/sheet/selector')
class SheetSelectorRoute extends GoRouteData with _$SheetSelectorRoute {
  const SheetSelectorRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SheetSelectorPage();
}

// ✅ RowEditorRoute
@TypedGoRoute<RowEditorRoute>(path: '/row')
class RowEditorRoute extends GoRouteData with _$RowEditorRoute {
  const RowEditorRoute({this.id});
  final String? id;

  @override
  Widget build(BuildContext context, GoRouterState state) => ProviderScope(
    overrides: [
      formProvider.overrideWith((ref) => {}),
    ],
    child: RowEditor(rowId_: id),
  );
}

// ✅ DebugRoute
@TypedGoRoute<DebugRoute>(path: '/debug')
class DebugRoute extends GoRouteData with _$DebugRoute {
  const DebugRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const DebugPage();
}

// ✅ LinkRecordRoute
@TypedGoRoute<LinkRecordRoute>(path: '/sheet/link_record/:columnId/:rowId')
class LinkRecordRoute extends GoRouteData with _$LinkRecordRoute {
  const LinkRecordRoute({
    required this.columnId,
    required this.rowId,
  });
  final String columnId;
  final String rowId;
  @override
  Widget build(BuildContext context, GoRouterState state) => LinkRecordPage(
    columnId: columnId,
    rowId: rowId,
  );
}
