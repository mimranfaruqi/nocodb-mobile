import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/features/core/components/navigation_drawer.dart';
import 'package:nocodb/features/core/components/view_switcher.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/routes.dart';

class SheetPage extends HookConsumerWidget {
  const SheetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final view = ref.watch(viewProvider);
    if (project == null || view == null) {
      return const CircularProgressIndicator();
    }

    return WillPopScope(
      onWillPop: () async {
        // When user presses back on sheet/view, go to project list instead of login
        const ProjectListRoute().go(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(view.title)),
        drawer: const AppNavigationDrawer(),
        drawerEdgeDragWidth: 20,
        body: const ViewSwitcher(),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final table = ref.watch(tableProvider);
            final currentView = ref.watch(viewProvider);
            if (table == null || currentView == null) {
              return;
            }
            await const RowEditorRoute().push(context);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
