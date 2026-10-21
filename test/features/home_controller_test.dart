import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/data/database/app_database.dart';
import 'package:snigea/data/models/app_settings.dart';
import 'package:snigea/data/models/media.dart';
import 'package:snigea/data/models/provider_kind.dart';
import 'package:snigea/features/home/home_controller.dart';
import 'package:snigea/providers/fourkhdhub/fourkhdhub_client.dart';
import 'package:snigea/providers/moviebox/moviebox_client.dart';
import 'package:snigea/state/app_providers.dart';

/// A MovieBox client that answers with a fixed catalogue.
class _FakeMovieBox extends MovieBoxClient {
  int calls = 0;

  @override
  Future<Object?> homepage(String tabId, int page) async {
    calls++;
    return {
      'items': [
        {
          'title': 'Trending movies',
          'subjects': [
            {'subjectId': '1', 'title': 'Inception', 'subjectType': 1},
          ],
        },
      ],
    };
  }
}

/// A 4KHDHub client that answers with a fixed catalogue.
class _FakeFourKHdHub extends FourKHdHubClient {
  int calls = 0;

  @override
  Future<List<CatalogItem>> latest() async {
    calls++;
    return const [
      CatalogItem(
        id: ProviderMediaId(provider: ProviderKind.fourkhdhub, value: '1'),
        title: 'Dune',
        mediaType: MediaType.movie,
      ),
    ];
  }
}

class _SettingsController extends SettingsController {
  _SettingsController(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> build() async => settings;
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('the home screen loads the catalogue of the active provider', () async {
    final movieBox = _FakeMovieBox();
    final fourKHdHub = _FakeFourKHdHub();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        movieBoxClientProvider.overrideWithValue(movieBox),
        fourKHdHubClientProvider.overrideWithValue(fourKHdHub),
        settingsProvider.overrideWith(
          () => _SettingsController(
            const AppSettings(activeProvider: ProviderKind.moviebox),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final movieBoxState = await container.read(
      homeControllerProvider(ProviderKind.moviebox).future,
    );
    expect(movieBox.calls, greaterThan(0));
    expect(movieBoxState.sections, isNotEmpty);
    expect(movieBoxState.sections.first.title, 'Trending movies');
    expect(fourKHdHub.calls, 0);

    // Switching the provider loads the catalogue of the new provider.
    await container
        .read(settingsProvider.notifier)
        .setActiveProvider(ProviderKind.fourkhdhub);

    final fourKState = await container.read(
      homeControllerProvider(ProviderKind.fourkhdhub).future,
    );
    expect(fourKHdHub.calls, greaterThan(0));
    expect(fourKState.sections, isNotEmpty);
    expect(fourKState.sections.first.title, 'Latest releases');
  });
}
