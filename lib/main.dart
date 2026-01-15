import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:nocodb/common/preferences.dart';
import 'package:nocodb/common/settings.dart';
import 'package:nocodb/common/directus_settings.dart';
import 'package:nocodb/directus_router.dart';
import 'package:stack_trace/stack_trace.dart';

const useMaterial3 = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
  }
  // https://api.flutter.dev/flutter/foundation/FlutterError/demangleStackTrace.html
  FlutterError.demangleStackTrace = (stack) {
    // Trace and Chain are classes in package:stack_trace
    if (stack is Trace) {
      return stack.vmTrace;
    }
    if (stack is Chain) {
      return stack.toTrace().vmTrace;
    }
    return stack;
  };

  runApp(const ProviderScope(child: App()));
}

class App extends HookConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(directusRouterProvider);

    return BackButtonInterceptor(
      child: GlobalLoaderOverlay(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: r,
          title: 'Directus Mobile',
          theme: useMaterial3
              ? ThemeData(useMaterial3: true, colorSchemeSeed: Colors.black)
              : ThemeData(useMaterial3: false, primarySwatch: Colors.blue),
          themeMode: ThemeMode.light,
        ),
      ),
    );
  }
}

class BackButtonInterceptor extends StatefulWidget {
  final Widget child;

  const BackButtonInterceptor({required this.child, super.key});

  @override
  State<BackButtonInterceptor> createState() => _BackButtonInterceptorState();
}

class _BackButtonInterceptorState extends State<BackButtonInterceptor> {
  DateTime? _lastBackPressTime;
  String _lastRoute = '/';

  @override
  void initState() {
    super.initState();
    // Listen to route changes to track current route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final router = GoRouter.of(context);
        router.routeInformationProvider.addListener(_updateRoute);
      }
    });
  }

  void _updateRoute() {
    if (mounted) {
      final router = GoRouter.of(context);
      final newRoute =
          router.routeInformationProvider.value.uri.toString();
      if (_lastRoute != newRoute) {
        _lastRoute = newRoute;
      }
    }
  }

  @override
  void dispose() {
    try {
      final router = GoRouter.of(context);
      router.routeInformationProvider.removeListener(_updateRoute);
    } catch (e, stackTrace) {
      // Context might not be available; log for debugging purposes.
      debugPrint('Error while removing route listener in dispose: $e');
      debugPrint(stackTrace.toString());
    }
    super.dispose();
  }

  Future<bool> _isUserLoggedIn() async {
    try {
      if (!directusSettings.initialized) {
        final prefs = Preferences();
        await prefs.load();
        directusSettings.init(prefs);
      }
      final credentials = await directusSettings.get();
      return credentials != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final isLoggedIn = await _isUserLoggedIn();
        final router = GoRouter.of(context);
        
        // Use cached route for faster check
        final currentRoute = _lastRoute;
        
        // If user is logged in, prevent back navigation to login
        if (isLoggedIn) {
          // Check if we're on main screens (collections list)
          final isMainScreen = currentRoute.startsWith('/directus/collections');
          
          if (isMainScreen) {
            // We're on a main screen - show exit confirmation
            final now = DateTime.now();
            final isSecondPress = _lastBackPressTime != null &&
                now.difference(_lastBackPressTime!) < const Duration(seconds: 2);

            if (isSecondPress) {
              // Close the app
              _lastBackPressTime = null;
              exit(0);
            } else {
              // Show notification on first press
              _lastBackPressTime = now;
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Press back again to exit'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
            // Don't navigate - completely prevent back button
            return;
          }
          
          // For nested screens, allow back navigation
          _lastBackPressTime = null;
          if (router.canPop()) {
            router.pop();
          }
        } else {
          // User not logged in - normal back navigation
          if (router.canPop()) {
            router.pop();
          } else {
            exit(0);
          }
        }
      },
      child: widget.child,
    );
}
