import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nocodb/common/directus_settings.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/common/preferences.dart';
import 'package:nocodb/directus_sdk/directus.dart';
import 'package:nocodb/features/directus/routes.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'directus_router.g.dart';

FutureOr<String?> directusRedirect(
  Ref ref,
  BuildContext context,
  GoRouterState state,
) async {
  try {
    // Initialize settings if needed
    if (!directusSettings.initialized) {
      final prefs = Preferences();
      await prefs.load();
      directusSettings.init(prefs);
      logger.fine('Loaded Directus settings from storage');
    }

    final credentials = await directusSettings.get();
    
    // If no credentials, redirect to sign-in
    if (credentials == null) {
      if (state.uri.toString() != const DirectusSignInRoute().location) {
        logger.info('No credentials found, redirecting to sign-in');
        return const DirectusSignInRoute().location;
      }
      return null;
    }

    // Initialize Directus client with stored credentials
    initDirectus(credentials.host, token: credentials.accessToken);

    // If user is authenticated and trying to access sign-in, redirect to collections
    if (state.uri.toString() == const DirectusSignInRoute().location) {
      logger.info('User authenticated, redirecting to collections');
      return const DirectusCollectionsRoute().location;
    }

    return null;
  } catch (e, s) {
    logger
      ..warning('Redirect error: $e')
      ..warning(s);
    return const DirectusSignInRoute().location;
  }
}

@riverpod
GoRouter directusRouter(Ref ref) => GoRouter(
  routes: $appRoutes,
  initialLocation: const DirectusSignInRoute().location,
  debugLogDiagnostics: true,
  redirect: (context, state) async {
    final location = await directusRedirect(ref, context, state);
    if (location != null) {
      logger.info('Redirected to $location');
    }
    return location;
  },
  navigatorKey: GlobalKey<NavigatorState>(),
);
