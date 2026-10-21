import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/details/details_page.dart';
import '../features/downloads/downloads_page.dart';
import '../features/home/home_page.dart';
import '../features/library/library_page.dart';
import '../features/player/player_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/app_shell.dart';

/// The router of the application.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SearchPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: LibraryPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/downloads',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DownloadsPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsPage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/title',
        builder: (context, state) => DetailsPage(
          provider: state.uri.queryParameters['provider'] ?? 'moviebox',
          id: state.uri.queryParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => PlayerPage(
          provider: state.uri.queryParameters['provider'] ?? 'moviebox',
          subjectId: state.uri.queryParameters['id'] ?? '',
          season: int.tryParse(state.uri.queryParameters['season'] ?? '0') ?? 0,
          episode:
              int.tryParse(state.uri.queryParameters['episode'] ?? '0') ?? 0,
          title: state.uri.queryParameters['title'] ?? '',
        ),
      ),
    ],
  );
});
