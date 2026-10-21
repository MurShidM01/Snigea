import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The Snigea database.
///
/// The schema keeps every user owned record (favourites, watchlist, playback
/// progress, watched episodes, search history, preferences, provider
/// configuration, cached metadata and download tasks) in a single SQLite
/// file inside the application support directory.
@DriftDatabase(
  tables: [
    SavedTitles,
    PlaybackProgress,
    WatchedEpisodes,
    SearchHistory,
    Settings,
    ProviderConfigs,
    MetadataCacheEntries,
    DownloadRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openSnigeaConnection());

  /// The database used by the tests, backed by an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
