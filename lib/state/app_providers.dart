import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/file_store.dart';
import '../data/database/app_database.dart';
import '../data/models/app_settings.dart';
import '../data/models/provider_kind.dart';
import '../providers/addons/addon_models.dart';
import '../data/repositories/download_repository.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../providers/addons/addon_client.dart';
import '../providers/addons/addon_provider.dart';
import '../providers/bdix/circleftp_client.dart';
import '../providers/bdix/dhakaflix_client.dart';
import '../providers/content_provider.dart';
import '../providers/dramachi/dramachi_client.dart';
import '../providers/fourkhdhub/fourkhdhub_client.dart';
import '../providers/moviebox/moviebox_client.dart';
import '../providers/moviebox/moviebox_session.dart';
import '../services/catalog_service.dart';
import '../services/download_engine.dart';
import '../services/download_service.dart';
import '../services/playback_service.dart';
import '../services/settings_service.dart';

/// The application database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// The favourites and watchlist repository.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(appDatabaseProvider)),
);

/// The playback progress repository.
final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(appDatabaseProvider)),
);

/// The key/value settings repository.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

/// The provider configuration repository.
final providerConfigRepositoryProvider = Provider<ProviderConfigRepository>(
  (ref) => ProviderConfigRepository(ref.watch(appDatabaseProvider)),
);

/// The metadata cache repository.
final metadataCacheRepositoryProvider = Provider<MetadataCacheRepository>(
  (ref) => MetadataCacheRepository(ref.watch(appDatabaseProvider)),
);

/// The download repository.
final downloadRepositoryProvider = Provider<DownloadRepository>(
  (ref) => DownloadRepository(ref.watch(appDatabaseProvider)),
);

/// The download tasks of the device.
final downloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  return repository.watchAll();
});

/// The search history repository.
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => SearchHistoryRepository(ref.watch(appDatabaseProvider)),
);

/// The file store of the current platform.
final fileStoreProvider = Provider<FileStore>((ref) => createFileStore());

/// The HTTP download engine.
final downloadEngineProvider = Provider<DownloadEngine>(
  (ref) => DownloadEngine(store: ref.watch(fileStoreProvider)),
);

/// The download orchestration.
final downloadServiceProvider = Provider<DownloadService>(
  (ref) => DownloadService(
    repository: ref.watch(downloadRepositoryProvider),
    fileStore: ref.watch(fileStoreProvider),
    engine: ref.watch(downloadEngineProvider),
    playbackService: ref.watch(playbackServiceProvider),
  ),
);

/// The settings service.
final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(
    ref.watch(settingsRepositoryProvider),
    ref.watch(providerConfigRepositoryProvider),
  ),
);

/// The catalogue service.
final catalogServiceProvider = Provider<CatalogService>(
  (ref) => CatalogService(
    cache: ref.watch(metadataCacheRepositoryProvider),
    providerConfigs: () => ref.read(providerConfigRepositoryProvider).all(),
  ),
);

/// The MovieBox client.
final movieBoxClientProvider = Provider<MovieBoxClient>((ref) {
  final client = MovieBoxClient(
    sessionStore: DbMovieBoxSessionStore(ref.watch(settingsRepositoryProvider)),
  );
  return client;
});

/// The 4KHDHub client.
final fourKHdHubClientProvider = Provider<FourKHdHubClient>(
  (ref) => FourKHdHubClient(),
);

/// The Dramachi client.
final dramachiClientProvider = Provider<DramachiClient>(
  (ref) => DramachiClient(),
);

/// The CircleFTP client.
final circleFtpClientProvider = Provider<CircleFtpClient>(
  (ref) => CircleFtpClient(),
);

/// The DhakaFlix client.
final dhakaFlixClientProvider = Provider<DhakaFlixClient>(
  (ref) => DhakaFlixClient(),
);

/// The Stremio addon client.
final addonClientProvider = Provider<AddonClient>((ref) => AddonClient());

/// The playback service.
final playbackServiceProvider = Provider<PlaybackService>(
  (ref) => PlaybackService(
    fourKHdHub: ref.watch(fourKHdHubClientProvider),
    movieBox: ref.watch(movieBoxClientProvider),
  ),
);

/// The list of installed Stremio addons.
final addonsProvider =
    AsyncNotifierProvider<AddonsController, List<InstalledAddon>>(
      AddonsController.new,
    );

/// Controls the installed Stremio addons.
class AddonsController extends AsyncNotifier<List<InstalledAddon>> {
  static const String _storageKey = 'installed_addons';

  @override
  Future<List<InstalledAddon>> build() async {
    final repository = ref.watch(settingsRepositoryProvider);
    final raw = await repository.read(_storageKey);
    final addons = _decode(raw);
    if (!addons.any((addon) => addon.isCore)) {
      final withCinemeta = [InstalledAddon.cinemetaDefault(), ...addons];
      await _persist(withCinemeta);
      return withCinemeta;
    }
    return addons;
  }

  /// Adds an addon from its manifest address.
  Future<void> install(String manifestUrl) async {
    final client = ref.read(addonClientProvider);
    final normalized = AddonClient.normalizeManifestUrl(manifestUrl);
    final manifest = await client.fetchManifest(normalized);
    final addon = InstalledAddon.fromManifest(normalized, manifest);

    final current = [...state.value ?? const <InstalledAddon>[]];
    final index = current.indexWhere(
      (entry) => entry.manifestUrl == addon.manifestUrl,
    );
    if (index >= 0) {
      current[index] = addon;
    } else {
      current.add(addon);
    }
    state = AsyncData(current);
    await _persist(current);
  }

  /// Removes an addon.
  Future<void> uninstall(InstalledAddon addon) async {
    final current = [...state.value ?? const <InstalledAddon>[]]
      ..removeWhere((entry) => entry.manifestUrl == addon.manifestUrl);
    state = AsyncData(current);
    await _persist(current);
  }

  /// Enables or disables an addon.
  Future<void> toggle(InstalledAddon addon) async {
    final current = [...state.value ?? const <InstalledAddon>[]];
    final index = current.indexWhere(
      (entry) => entry.manifestUrl == addon.manifestUrl,
    );
    if (index < 0) return;
    current[index] = current[index].copyWith(enabled: !current[index].enabled);
    state = AsyncData(current);
    await _persist(current);
  }

  Future<void> _persist(List<InstalledAddon> addons) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.write(
      _storageKey,
      jsonEncode(addons.map((addon) => addon.toJson()).toList()),
    );
  }

  static List<InstalledAddon> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, Object?>>()
          .map(InstalledAddon.fromJson)
          .toList();
    } on FormatException {
      return const [];
    }
  }
}

/// The registry of the available content providers.
final providerRegistryProvider = Provider<Map<ProviderKind, ContentProvider>>((
  ref,
) {
  return {
    ProviderKind.moviebox: ref.watch(movieBoxClientProvider),
    ProviderKind.fourkhdhub: ref.watch(fourKHdHubClientProvider),
    ProviderKind.dramachi: ref.watch(dramachiClientProvider),
    ProviderKind.bdixCircleFtp: ref.watch(circleFtpClientProvider),
    ProviderKind.bdixDhakaFlix: ref.watch(dhakaFlixClientProvider),
    ProviderKind.addons: AddonProvider(
      client: ref.watch(addonClientProvider),
      addons: () => ref.read(addonsProvider).value ?? const [],
    ),
  };
});

/// The user preferences.
final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Controls the user preferences.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final service = ref.watch(settingsServiceProvider);
    final settings = await service.load();

    // Make sure that every provider has a configuration row.
    final configs = await ref.read(providerConfigRepositoryProvider).all();
    for (final provider in ProviderKind.values) {
      if (!configs.containsKey(provider)) {
        await ref
            .read(providerConfigRepositoryProvider)
            .save(ProviderSettings(provider: provider));
      }
    }
    return settings;
  }

  /// Stores new preferences.
  Future<void> saveSettings(AppSettings settings) async {
    state = AsyncData(settings);
    await ref.read(settingsServiceProvider).save(settings);
  }

  /// Enables or disables a provider.
  Future<void> toggleProvider(ProviderKind provider) async {
    final settings = state.value ?? const AppSettings();
    final enabled = <ProviderKind>{...settings.enabledProviders};
    if (enabled.contains(provider)) {
      if (enabled.length == 1) return;
      enabled.remove(provider);
    } else {
      enabled.add(provider);
    }
    await saveSettings(settings.copyWith(enabledProviders: enabled));
    final repository = ref.read(providerConfigRepositoryProvider);
    final configs = await repository.all();
    final config = configs[provider] ?? ProviderSettings(provider: provider);
    await repository.save(
      ProviderSettings(
        provider: provider,
        enabled: enabled.contains(provider),
        baseUrl: config.baseUrl,
        extra: config.extra,
      ),
    );
  }

  /// Selects the active provider.
  Future<void> setActiveProvider(ProviderKind provider) async {
    final settings = state.value ?? const AppSettings();
    await saveSettings(settings.copyWith(activeProvider: provider));
  }
}

/// A [MovieBoxSessionStore] that persists the session in the settings table.
class DbMovieBoxSessionStore implements MovieBoxSessionStore {
  DbMovieBoxSessionStore(this._repository);

  static const String _key = 'moviebox_session';

  final SettingsRepository _repository;

  @override
  Future<MovieBoxSession?> load() async {
    final raw = await _repository.read(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      return MovieBoxSession.fromJson(json.cast<String, Object?>());
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(MovieBoxSession session) async {
    await _repository.write(_key, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    await _repository.remove(_key);
  }
}
