import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/theme/app_theme.dart';
import 'package:snigea/data/database/app_database.dart';
import 'package:snigea/data/models/app_settings.dart';
import 'package:snigea/data/models/media.dart';
import 'package:snigea/data/models/provider_kind.dart';
import 'package:snigea/data/repositories/download_repository.dart';
import 'package:snigea/data/repositories/library_repository.dart';
import 'package:snigea/data/repositories/progress_repository.dart';
import 'package:snigea/data/repositories/settings_repository.dart';
import 'package:snigea/features/details/details_page.dart';
import 'package:snigea/features/downloads/downloads_page.dart';
import 'package:snigea/features/home/home_page.dart';
import 'package:snigea/features/library/library_page.dart';
import 'package:snigea/features/search/search_page.dart';
import 'package:snigea/features/settings/settings_page.dart';
import 'package:snigea/providers/addons/addon_models.dart';
import 'package:snigea/providers/content_provider.dart';
import 'package:snigea/state/app_providers.dart';

import '../helpers/fake_clients.dart';

/// A provider that answers with a fixed catalogue.
class _FakeProvider implements ContentProvider {
  @override
  ProviderKind get id => ProviderKind.moviebox;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async =>
      _items;

  @override
  Future<MediaDetails> details(String id) async => _details;
}

const List<CatalogItem> _items = [
  CatalogItem(
    id: ProviderMediaId(provider: ProviderKind.moviebox, value: '1'),
    title: 'Inception',
    mediaType: MediaType.movie,
    year: '2010',
  ),
  CatalogItem(
    id: ProviderMediaId(provider: ProviderKind.moviebox, value: '2'),
    title: 'Breaking Bad',
    mediaType: MediaType.series,
    year: '2008',
    seasonCount: 5,
  ),
];

const MediaDetails _details = MediaDetails(
  id: ProviderMediaId(provider: ProviderKind.moviebox, value: '1'),
  title: 'Inception',
  mediaType: MediaType.movie,
  year: '2010',
  description:
      'A thief who steals corporate secrets through dream-sharing technology '
      'is given the inverse task of planting an idea.',
  imdbRating: '8.8',
  director: 'Christopher Nolan',
  duration: '2h 28m',
  genres: ['Action', 'Sci-Fi', 'Thriller'],
  seasons: [
    Season(
      number: 1,
      episodes: [
        Episode(season: 1, number: 1, title: 'Pilot'),
        Episode(season: 1, number: 2, title: "Cat's in the Bag..."),
      ],
    ),
  ],
);

class _SettingsController extends SettingsController {
  _SettingsController(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> build() async => settings;
}

class _AddonsController extends AddonsController {
  @override
  Future<List<InstalledAddon>> build() async => const [];
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  for (final mode in [SnigeaThemeMode.dark, SnigeaThemeMode.light]) {
    testWidgets('every screen builds in the ${mode.label} theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final overrides = [
        appDatabaseProvider.overrideWithValue(database),
        settingsProvider.overrideWith(
          () => _SettingsController(AppSettings(themeMode: mode)),
        ),
        providerRegistryProvider.overrideWithValue({
          ProviderKind.moviebox: _FakeProvider(),
        }),
        movieBoxClientProvider.overrideWithValue(FakeMovieBoxClient()),
        fourKHdHubClientProvider.overrideWithValue(FakeFourKHdHubClient()),
        dramachiClientProvider.overrideWithValue(FakeDramachiClient()),
        addonsProvider.overrideWith(_AddonsController.new),
        // The database streams are replaced by static values so that the
        // render does not depend on the drift timers.
        libraryEntriesProvider.overrideWith(
          (ref, kind) => const Stream<List<LibraryEntry>>.empty(),
        ),
        progressEntriesProvider.overrideWith(
          (ref) => const Stream<List<ProgressEntry>>.empty(),
        ),
        downloadTasksProvider.overrideWith(
          (ref) => const Stream<List<DownloadTask>>.empty(),
        ),
        searchHistoryProvider.overrideWith(
          (ref) async => const <SearchHistoryEntry>[],
        ),
      ];

      final screens = <String, Widget>{
        'home': const HomePage(),
        'search': const SearchPage(),
        'library': const LibraryPage(),
        'downloads': const DownloadsPage(),
        'settings': const SettingsPage(),
        'details': const DetailsPage(provider: 'moviebox', id: '1'),
      };

      for (final entry in screens.entries) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(
              theme: mode.themeMode == ThemeMode.dark
                  ? AppTheme.dark()
                  : AppTheme.light(),
              home: Scaffold(body: entry.value),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester.takeException(),
          isNull,
          reason:
              'the ${entry.key} screen must build in the ${mode.label} theme',
        );
      }
    });
  }
}
