import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'state/app_providers.dart';
import 'routing/app_router.dart';

/// The root widget of Snigea.
class SnigeaApp extends ConsumerWidget {
  const SnigeaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode =
        ref.watch(settingsProvider).value?.themeMode.themeMode ??
        ThemeMode.system;
    return MaterialApp.router(
      title: 'Snigea',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
