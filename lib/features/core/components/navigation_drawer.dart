import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nocodb/common/settings.dart';
import 'package:nocodb/features/core/components/filter_panel.dart';
import 'package:nocodb/features/core/providers/providers.dart';
import 'package:nocodb/features/core/providers/utils.dart';
import 'package:nocodb/routes.dart';

/// A hierarchical navigation drawer showing tables and their views
class AppNavigationDrawer extends HookConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedTableId = useState<String?>(null);

    return Drawer(
      child: Builder(
        builder: (context) {
          final project = ref.watch(projectProvider);

          // If no project is selected, drawer is not useful
          if (project == null) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'No project selected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Go to Projects'),
                  onTap: () {
                    Navigator.pop(context);
                    const ProjectListRoute().go(context);
                  },
                ),
              ],
            );
          }

          final tableList = ref.watch(tableListProvider(project.id));
          final currentTable = ref.watch(tableProvider);
          final currentView = ref.watch(viewProvider);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  key: const PageStorageKey('navDrawerList'),
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            project.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (currentTable != null)
                            Text(
                              currentTable.title,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
              ref
                  .watch(tableListProvider(project.id))
                  .when(
                    data: (tables) => Column(
                      children: tables.list.map((table) {
                        final isTableSelected = currentTable?.id == table.id;
                        final isExpanded = expandedTableId.value == table.id;
                        
                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                isExpanded 
                                  ? Icons.expand_less 
                                  : Icons.expand_more,
                              ),
                              title: Text(
                                table.title,
                                style: TextStyle(
                                  fontWeight: isTableSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: isTableSelected,
                              onTap: () async {
                                // Toggle expansion - collapse if already expanded, expand otherwise
                                if (isExpanded) {
                                  expandedTableId.value = null;
                                } else {
                                  expandedTableId.value = table.id;
                                }
                              },
                            ),
                            // Show views only if this table is expanded
                            if (isExpanded)
                              ref
                                  .watch(viewListProvider(table.id))
                                  .when(
                                    data: (views) => Column(
                                      children: views.list.map((view) {
                                        final isViewSelected =
                                            currentView?.id == view.id;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            left: 32.0,
                                          ),
                                          child: ListTile(
                                            leading: const Icon(
                                              Icons.view_agenda,
                                              size: 18,
                                            ),
                                            title: Text(
                                              view.title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isViewSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            selected: isViewSelected,
                                            onTap: () async {
                                              // When selecting a view, use selectView to properly update all providers
                                              await selectView(ref, view);
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                              }
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    loading: () => const Padding(
                                      padding: EdgeInsets.only(left: 32.0),
                                      child: SizedBox(
                                        height: 40,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    error: (error, stack) => Padding(
                                      padding: const EdgeInsets.only(left: 32.0),
                                      child: ListTile(
                                        title: Text('Error: $error'),
                                      ),
                                    ),
                                  ),
                          ],
                        );
                      }).toList(),
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) =>
                        ListTile(title: Text('Error: $error')),
                  ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.pop(context);
                  await settings.clear().then(
                    (value) => const HomeRoute().replace(context),
                  );
                },
              ),
                  ],
                ),
              ),
              const Divider(),
              const FilterPanel(),
            ],
          );
        },
      ),
    );
  }
}

