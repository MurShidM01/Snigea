import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../data/repositories/download_repository.dart';
import '../../state/app_providers.dart';
import '../../widgets/logo.dart';

/// The application shell that hosts the bottom navigation.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_Destination> _destinations = [
    _Destination('Home', Icons.home_outlined, Icons.home),
    _Destination('Search', Icons.search_outlined, Icons.search),
    _Destination('Library', Icons.bookmark_outline, Icons.bookmark),
    _Destination('Downloads', Icons.download_outlined, Icons.download),
    _Destination('Settings', Icons.settings_outlined, Icons.settings),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 900;
    final activeDownloads = ref.watch(activeDownloadsProvider);

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 88,
              color: context.colors.surface,
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Center(child: SnigeaLogo(size: 30)),
                    const SizedBox(height: 10),
                    const SizedBox(height: 18),
                    Expanded(
                      child: NavigationRail(
                        selectedIndex: navigationShell.currentIndex,
                        onDestinationSelected: (index) => _goBranch(index),
                        labelType: NavigationRailLabelType.all,
                        groupAlignment: -0.85,
                        destinations: [
                          for (final destination in _destinations)
                            NavigationRailDestination(
                              icon: _railIcon(
                                context,
                                destination,
                                activeDownloads,
                              ),
                              selectedIcon: _railIcon(
                                context,
                                destination,
                                activeDownloads,
                              ),
                              label: Text(destination.label),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    // The navigation bar is drawn edge to edge: its background reaches the
    // system navigation bar of the device and no separator line is painted
    // between the two.
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        elevation: 0,
        // The same colour as the canvas, so the bar and the system
        // navigation area form one continuous surface.
        backgroundColor: context.colors.background,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: _railIcon(context, destination, activeDownloads),
              selectedIcon: _railIcon(context, destination, activeDownloads),
              label: destination.label,
            ),
        ],
      ),
    );
  }

  Widget _railIcon(
    BuildContext context,
    _Destination destination,
    int activeDownloads,
  ) {
    final icon = Icon(destination.icon);
    if (destination.label != 'Downloads' || activeDownloads == 0) {
      return icon;
    }
    return Badge.count(
      count: activeDownloads,
      backgroundColor: context.colors.accent,
      textColor: Colors.white,
      child: icon,
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The number of downloads that are currently running.
final activeDownloadsProvider = Provider<int>((ref) {
  final tasks = ref.watch(downloadTasksProvider);
  return tasks.value
          ?.where(
            (task) =>
                task.status == DownloadStatus.running ||
                task.status == DownloadStatus.queued,
          )
          .length ??
      0;
});
