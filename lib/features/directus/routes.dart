import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nocodb/features/directus/pages/sign_in.dart';
import 'package:nocodb/features/directus/pages/collections.dart';
import 'package:nocodb/features/directus/pages/items.dart';
import 'package:nocodb/features/directus/pages/item_editor.dart';

part 'routes.g.dart';

@TypedGoRoute<DirectusSignInRoute>(
  path: '/directus',
  routes: [
    TypedGoRoute<DirectusCollectionsRoute>(
      path: 'collections',
    ),
    TypedGoRoute<DirectusItemsRoute>(
      path: 'items/:collection',
    ),
    TypedGoRoute<DirectusItemEditorRoute>(
      path: 'editor/:collection',
    ),
  ],
)
class DirectusSignInRoute extends GoRouteData with $DirectusSignInRoute {
  const DirectusSignInRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DirectusSignInPage();
}

class DirectusCollectionsRoute extends GoRouteData with $DirectusCollectionsRoute {
  const DirectusCollectionsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DirectusCollectionsPage();
}

class DirectusItemsRoute extends GoRouteData with $DirectusItemsRoute {
  const DirectusItemsRoute({required this.collection});

  final String collection;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DirectusItemsPage(collection: collection);
}

class DirectusItemEditorRoute extends GoRouteData with $DirectusItemEditorRoute {
  const DirectusItemEditorRoute({
    required this.collection,
    this.itemId,
  });

  final String collection;
  final String? itemId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DirectusItemEditorPage(
        collection: collection,
        itemId: itemId,
      );
}
