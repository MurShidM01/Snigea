import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:snigea/providers/moviebox/moviebox_client.dart';
import 'package:snigea/state/app_providers.dart';
import 'package:snigea/widgets/logo.dart';

import '../helpers/fake_clients.dart';

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

/// A MovieBox client that answers with a filled catalogue.
class _RichMovieBoxClient extends MovieBoxClient {
  @override
  Future<Object?> homepage(String tabId, int page) async => {
    'items': [
      {
        'title': 'Trending now',
        'subjects': [
          for (final entry in _catalogue.entries.take(6))
            {
              'subjectId': entry.key,
              'title': entry.value.$1,
              'subjectType': entry.value.$2,
              'releaseDate': entry.value.$3,
            },
        ],
      },
      {
        'title': 'Popular series',
        'subjects': [
          for (final entry in _catalogue.entries.skip(2).take(6))
            {
              'subjectId': entry.key,
              'title': entry.value.$1,
              'subjectType': 2,
              'releaseDate': entry.value.$3,
            },
        ],
      },
    ],
  };
}

const Map<String, (String, int, String, String)> _catalogue = {
  '1300291': ('Inception', 1, '2010-07-16', 'https://example.invalid/1.jpg'),
  '1295644': ('Interstellar', 1, '2014-11-05', 'https://example.invalid/2.jpg'),
  '1217411': ('Breaking Bad', 2, '2008-01-20', 'https://example.invalid/3.jpg'),
  '1422942': (
    'Dune: Part Two',
    1,
    '2024-02-27',
    'https://example.invalid/4.jpg',
  ),
  '1157020': (
    'Game of Thrones',
    2,
    '2011-04-17',
    'https://example.invalid/5.jpg',
  ),
  '1198155': (
    'The Dark Knight',
    1,
    '2008-07-16',
    'https://example.invalid/6.jpg',
  ),
  '1124802': (
    'The Last of Us',
    2,
    '2023-01-15',
    'https://example.invalid/7.jpg',
  ),
  '1268300': ('Oppenheimer', 1, '2023-07-19', 'https://example.invalid/8.jpg'),
};

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

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = await File(file).readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  late AppDatabase database;

  setUpAll(() async {
    const fonts =
        '/workspaces/codespaces-blank/flutter-sdk/flutter/bin/cache/artifacts/material_fonts';
    await _loadFont('Roboto', [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Medium.ttf',
      '$fonts/Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('capture the screens', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final overrides = [
      appDatabaseProvider.overrideWithValue(database),
      settingsProvider.overrideWith(
        () => _SettingsController(
          const AppSettings(themeMode: SnigeaThemeMode.dark),
        ),
      ),
      providerRegistryProvider.overrideWithValue({
        ProviderKind.moviebox: _FakeProvider(),
      }),
      movieBoxClientProvider.overrideWithValue(_RichMovieBoxClient()),
      fourKHdHubClientProvider.overrideWithValue(FakeFourKHdHubClient()),
      dramachiClientProvider.overrideWithValue(FakeDramachiClient()),
      addonsProvider.overrideWith(_AddonsController.new),
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
      'details': const DetailsPage(provider: 'moviebox', id: '1'),
      'library': const LibraryPage(),
      'downloads': const DownloadsPage(),
      'settings': const SettingsPage(),
    };

    // The rendered pictures are stored next to the other golden images, they
    // never overwrite the device screenshots of the README.
    final directory = Directory('goldens/screenshots');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    for (final entry in screens.entries) {
      final theme = AppTheme.dark();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: theme.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: ValueKey('capture-${entry.key}'),
                child: entry.value,
              ),
            ),
          ),
        ),
      );
      // The logo is an asset, the image has to be decoded in a real async
      // zone before the capture can paint it.
      final logo = find.byType(SnigeaLogo);
      if (logo.evaluate().isNotEmpty) {
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/icon/snigea_logo.png'),
            tester.element(logo.first),
          );
        });
      }
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byKey(ValueKey('capture-${entry.key}')),
        matchesGoldenFile('goldens/screenshots/${entry.key}.png'),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
