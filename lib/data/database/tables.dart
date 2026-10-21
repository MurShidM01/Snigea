import 'package:drift/drift.dart';

/// A saved title (favourite or watchlist entry).
class SavedTitles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get provider => text()();
  TextColumn get subjectId => text()();
  TextColumn get title => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get mediaType => text()();
  TextColumn get year => text().nullable()();
  TextColumn get releaseLabel => text().nullable()();
  IntColumn get addedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {kind, provider, subjectId, mediaType},
  ];
}

/// The playback position of a title, movie or episode.
class PlaybackProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text()();
  TextColumn get subjectId => text()();
  TextColumn get title => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get mediaType => text()();
  TextColumn get year => text().nullable()();
  IntColumn get season => integer().withDefault(const Constant(0))();
  IntColumn get episode => integer().withDefault(const Constant(0))();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  TextColumn get sourceLabel => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {provider, subjectId, season, episode},
  ];
}

/// An episode that has been watched to the end.
class WatchedEpisodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text()();
  TextColumn get subjectId => text()();
  TextColumn get title => text()();
  IntColumn get season => integer().withDefault(const Constant(0))();
  IntColumn get episode => integer().withDefault(const Constant(0))();
  IntColumn get watchedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {provider, subjectId, season, episode},
  ];
}

/// A previously issued search query.
class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  TextColumn get provider => text()();
  IntColumn get resultCount => integer().withDefault(const Constant(0))();
  IntColumn get searchedAt => integer()();
}

/// A user preference.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The configuration of a single provider.
class ProviderConfigs extends Table {
  TextColumn get provider => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get extra => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {provider};
}

/// A cached metadata payload.
class MetadataCacheEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cacheKey => text()();
  TextColumn get provider => text()();
  TextColumn get subjectId => text()();
  TextColumn get payload => text()();
  IntColumn get fetchedAt => integer()();
  IntColumn get expiresAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {cacheKey},
  ];
}

/// A download task and its state.
class DownloadRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text()();
  TextColumn get subjectId => text()();
  TextColumn get title => text()();
  IntColumn get season => integer().withDefault(const Constant(0))();
  IntColumn get episode => integer().withDefault(const Constant(0))();
  TextColumn get url => text()();
  TextColumn get headersJson => text().nullable()();
  TextColumn get fileName => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get filePath => text().nullable()();
  IntColumn get totalBytes => integer().nullable()();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  TextColumn get error => text().nullable()();
  TextColumn get integrity => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}
