import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/app.dart';
import 'package:snigea/data/database/app_database.dart';
import 'package:snigea/data/models/app_settings.dart';
import 'package:snigea/data/repositories/download_repository.dart';
import 'package:snigea/data/repositories/library_repository.dart';
import 'package:snigea/data/repositories/progress_repository.dart';
import 'package:snigea/features/library/library_page.dart';
import 'package:snigea/state/app_providers.dart';

import '../helpers/fake_clients.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('the app renders in the dark theme', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsProvider.overrideWith(
            () => _SettingsController(
              const AppSettings(themeMode: SnigeaThemeMode.dark),
            ),
          ),
          // No provider is registered, so the app does not reach the network
          // while the test runs.
          providerRegistryProvider.overrideWithValue(const {}),
          // The clients answer with an empty catalogue, so the render does
          // not reach the network.
          movieBoxClientProvider.overrideWithValue(FakeMovieBoxClient()),
          fourKHdHubClientProvider.overrideWithValue(FakeFourKHdHubClient()),
          dramachiClientProvider.overrideWithValue(FakeDramachiClient()),
          // The database streams are replaced by static values, so the
          // render does not depend on the drift timers.
          downloadTasksProvider.overrideWith(
            (ref) => const Stream<List<DownloadTask>>.empty(),
          ),
          libraryEntriesProvider.overrideWith(
            (ref, kind) => const Stream<List<LibraryEntry>>.empty(),
          ),
          progressEntriesProvider.overrideWith(
            (ref) => const Stream<List<ProgressEntry>>.empty(),
          ),
        ],
        child: const SnigeaApp(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('SNIGEA'), findsOneWidget);
  });

  testWidgets('the app renders in the light theme', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsProvider.overrideWith(
            () => _SettingsController(
              const AppSettings(themeMode: SnigeaThemeMode.light),
            ),
          ),
          providerRegistryProvider.overrideWithValue(const {}),
          // The clients answer with an empty catalogue, so the render does
          // not reach the network.
          movieBoxClientProvider.overrideWithValue(FakeMovieBoxClient()),
          fourKHdHubClientProvider.overrideWithValue(FakeFourKHdHubClient()),
          dramachiClientProvider.overrideWithValue(FakeDramachiClient()),
          // The database streams are replaced by static values, so the
          // render does not depend on the drift timers.
          downloadTasksProvider.overrideWith(
            (ref) => const Stream<List<DownloadTask>>.empty(),
          ),
          libraryEntriesProvider.overrideWith(
            (ref, kind) => const Stream<List<LibraryEntry>>.empty(),
          ),
          progressEntriesProvider.overrideWith(
            (ref) => const Stream<List<ProgressEntry>>.empty(),
          ),
        ],
        child: const SnigeaApp(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('SNIGEA'), findsOneWidget);
  });

  testWidgets('the navigation bar marks the active tab with the accent only', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsProvider.overrideWith(
            () => _SettingsController(
              const AppSettings(themeMode: SnigeaThemeMode.dark),
            ),
          ),
          // No provider is registered, so the app does not reach the network
          // while the test runs.
          providerRegistryProvider.overrideWithValue(const {}),
          // The clients answer with an empty catalogue, so the render does
          // not reach the network.
          movieBoxClientProvider.overrideWithValue(FakeMovieBoxClient()),
          fourKHdHubClientProvider.overrideWithValue(FakeFourKHdHubClient()),
          dramachiClientProvider.overrideWithValue(FakeDramachiClient()),
          // The database streams are replaced by static values, so the
          // render does not depend on the drift timers.
          downloadTasksProvider.overrideWith(
            (ref) => const Stream<List<DownloadTask>>.empty(),
          ),
          libraryEntriesProvider.overrideWith(
            (ref, kind) => const Stream<List<LibraryEntry>>.empty(),
          ),
          progressEntriesProvider.overrideWith(
            (ref) => const Stream<List<ProgressEntry>>.empty(),
          ),
        ],
        child: const SnigeaApp(),
      ),
    );
    await tester.pump();

    final theme = Theme.of(tester.element(find.byType(NavigationBar)));
    expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);

    // The home destination is rendered with its outline icon.
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });
}

class _SettingsController extends SettingsController {
  _SettingsController(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> build() async => settings;
}
