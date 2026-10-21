import 'package:drift/drift.dart';

import '../models/media.dart';
import '../models/provider_kind.dart';
import '../database/app_database.dart';

/// A stored playback position.
class ProgressEntry {
  const ProgressEntry({
    required this.provider,
    required this.subjectId,
    required this.title,
    required this.mediaType,
    required this.positionMs,
    this.season = 0,
    this.episode = 0,
    required this.updatedAt,
    this.posterUrl,
    this.year,
    this.durationMs,
    this.completed = false,
    this.sourceLabel,
    this.sourceUrl,
  });

  final ProviderKind provider;
  final String subjectId;
  final String title;
  final MediaType mediaType;
  final int season;
  final int episode;
  final int positionMs;
  final int? durationMs;
  final bool completed;
  final String? posterUrl;
  final String? year;
  final String? sourceLabel;
  final String? sourceUrl;
  final int updatedAt;

  /// The progress in percent, or `null` when the duration is unknown.
  double? get fraction {
    final duration = durationMs;
    if (duration == null || duration <= 0) return null;
    return (positionMs / duration).clamp(0.0, 1.0);
  }

  /// True when the entry can be resumed.
  ///
  /// The rule matches the reference implementation: at least 30 seconds
  /// watched and less than 90 % of the duration.
  bool get isResumable {
    if (completed) return false;
    if (positionMs < 30000) return false;
    final duration = durationMs;
    if (duration == null || duration <= 0) return false;
    return positionMs < duration * 0.9;
  }
}

/// Stores the playback progress and the watched episodes.
class ProgressRepository {
  ProgressRepository(this._db);

  final AppDatabase _db;

  /// Saves (or updates) the playback position of a title.
  Future<void> save(ProgressEntry entry) async {
    await _db.transaction(() async {
      await _db
          .into(_db.playbackProgress)
          .insert(
            PlaybackProgressCompanion.insert(
              provider: entry.provider.cacheKey,
              subjectId: entry.subjectId,
              title: entry.title,
              mediaType: entry.mediaType.wireName,
              season: Value(entry.season),
              episode: Value(entry.episode),
              positionMs: Value(entry.positionMs),
              durationMs: Value(entry.durationMs),
              completed: Value(entry.completed),
              posterUrl: Value(entry.posterUrl),
              year: Value(entry.year),
              sourceLabel: Value(entry.sourceLabel),
              sourceUrl: Value(entry.sourceUrl),
              updatedAt: entry.updatedAt,
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  /// Loads the playback position of a specific title.
  Future<ProgressEntry?> entry(
    ProviderKind provider,
    String subjectId, {
    int season = 0,
    int episode = 0,
  }) async {
    final row =
        await (_db.select(_db.playbackProgress)..where(
              (row) =>
                  row.provider.equals(provider.cacheKey) &
                  row.subjectId.equals(subjectId) &
                  row.season.equals(season) &
                  row.episode.equals(episode),
            ))
            .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  /// Loads every stored position, most recent first.
  Future<List<ProgressEntry>> all() async {
    final rows = await (_db.select(
      _db.playbackProgress,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).get();
    return rows.map(_toModel).toList();
  }

  /// Watches every stored position, most recent first.
  Stream<List<ProgressEntry>> watchAll() {
    final query = _db.select(_db.playbackProgress)
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toModel).toList());
  }

  /// The titles that can be continued.
  Future<List<ProgressEntry>> continueWatching({int limit = 20}) async {
    final entries = await all();
    return entries.where((entry) => entry.isResumable).take(limit).toList();
  }

  /// Removes the stored position of a title.
  Future<void> remove(
    ProviderKind provider,
    String subjectId, {
    int season = 0,
    int episode = 0,
  }) async {
    await (_db.delete(_db.playbackProgress)..where(
          (row) =>
              row.provider.equals(provider.cacheKey) &
              row.subjectId.equals(subjectId) &
              row.season.equals(season) &
              row.episode.equals(episode),
        ))
        .go();
  }

  /// Marks an episode as watched.
  Future<void> markWatched({
    required ProviderKind provider,
    required String subjectId,
    required String title,
    int season = 0,
    int episode = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _db
          .into(_db.watchedEpisodes)
          .insert(
            WatchedEpisodesCompanion.insert(
              provider: provider.cacheKey,
              subjectId: subjectId,
              title: title,
              season: Value(season),
              episode: Value(episode),
              watchedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  /// The episodes that have been watched for a series.
  Future<Set<int>> watchedEpisodeNumbers(
    ProviderKind provider,
    String subjectId,
  ) async {
    final rows =
        await (_db.select(_db.watchedEpisodes)..where(
              (row) =>
                  row.provider.equals(provider.cacheKey) &
                  row.subjectId.equals(subjectId),
            ))
            .get();
    return rows.map((row) => row.episode).toSet();
  }

  /// True when the episode has been watched.
  Future<bool> isWatched(
    ProviderKind provider,
    String subjectId,
    int season,
    int episode,
  ) async {
    final row =
        await (_db.select(_db.watchedEpisodes)..where(
              (row) =>
                  row.provider.equals(provider.cacheKey) &
                  row.subjectId.equals(subjectId) &
                  row.season.equals(season) &
                  row.episode.equals(episode),
            ))
            .getSingleOrNull();
    return row != null;
  }

  ProgressEntry _toModel(PlaybackProgressData row) => ProgressEntry(
    provider: ProviderKind.tryParse(row.provider) ?? ProviderKind.moviebox,
    subjectId: row.subjectId,
    title: row.title,
    mediaType: MediaType.fromWire(row.mediaType),
    season: row.season,
    episode: row.episode,
    positionMs: row.positionMs,
    durationMs: row.durationMs,
    completed: row.completed,
    posterUrl: row.posterUrl,
    year: row.year,
    sourceLabel: row.sourceLabel,
    sourceUrl: row.sourceUrl,
    updatedAt: row.updatedAt,
  );
}
