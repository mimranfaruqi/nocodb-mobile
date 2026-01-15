import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/common/preferences.dart';
import 'package:nocodb/common/settings.dart';
import 'package:nocodb/nocodb_sdk/client.dart';
import 'package:nocodb/nocodb_sdk/utils.dart';
import 'package:nocodb/routes.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

(Map<String, dynamic> header, Map<String, dynamic> payload) decodeJwt(
  String jwt,
) {
  final parts = jwt.split('.');
  assert(parts.length == 3);

  final rawHeader = parts[0];
  final rawPayload = parts[1];

  final header = String.fromCharCodes(
    base64Decode(base64.normalize(rawHeader)),
  );
  final payload = String.fromCharCodes(
    base64Decode(base64.normalize(rawPayload)),
  );
  return (jsonDecode(header), jsonDecode(payload));
}

DateTime jwtTsToDateTime(int timestamp) =>
    DateTime.fromMicrosecondsSinceEpoch(timestamp * 1000 * 1000);

(DateTime iat, DateTime exp) getIatAndExpFromPayload(
  Map<String, dynamic> payload,
) => (jwtTsToDateTime(payload['iat']), jwtTsToDateTime(payload['exp']));

bool isAuthTokenAlive(String authToken) {
  final (header, payload) = decodeJwt(authToken);
  logger.fine('authToken.header: $header');

  final (iat, exp) = getIatAndExpFromPayload(payload);
  final now = DateTime.now();
  logger
    ..fine('authToken.iat: $iat')
    ..fine('authToken.exp: $exp')
    ..fine('now: $now');

  return now.isBefore(exp);
}

FutureOr<String?> redirect(
  Ref ref,
  BuildContext context,
  GoRouterState state,
) async {
  try {
    if (!settings.initialized) {
      final prefs = Preferences();
      await prefs.load();
      settings.init(prefs);
      logger.fine('loaded settings from storage.');
    }

    final s = await settings.get();
    if (s == null) {
      await settings.clear();
      // Only redirect to HomeRoute if not already there
      if (state.uri.toString() != const HomeRoute().location) {
        return const HomeRoute().location;
      }
      return null;
    }
    final Settings(:host, :token, :baseId) = s;

    logger
      ..config('host: $host')
      ..config('state.uri: ${state.uri}');

    // Check if token is expired
    if (token is AuthToken && !isAuthTokenAlive(token.authToken)) {
      logger.info('authToken is expired.');
      await settings.clear();
      if (state.uri.toString() != const HomeRoute().location) {
        return const HomeRoute().location;
      }
      return null;
    }

    // If user is authenticated and trying to access login page, redirect to appropriate page
    if (state.uri.toString() == const HomeRoute().location) {
      api.init(host, token: token);
      // After login, always go to project list first, not directly to a sheet
      // This gives user a chance to select a project and navigate properly
      if (isCloud(host)) {
        return const CloudProjectListRoute().location;
      } else {
        return const ProjectListRoute().location;
      }
    }

    // For all other routes, ensure API is initialized with credentials
    api.init(host, token: token);
  } catch (e, s) {
    logger
      ..warning(e)
      ..warning(s);
    return const HomeRoute().location;
  }

  return null;
}

@riverpod
GoRouter router(Ref ref) => GoRouter(
  routes: $appRoutes,
  debugLogDiagnostics: true,
  redirect: (context, state) async {
    final location = await redirect(ref, context, state);
    if (location != null) {
      logger.info('redirected to $location');
    }
    return location;
  },
  navigatorKey: GlobalKey<NavigatorState>(),
);
