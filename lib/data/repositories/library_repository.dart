import 'package:drift/drift.dart';

import '../models/media.dart';
import '../models/provider_kind.dart';
import '../database/app_database.dart';

/// The kind of a saved title.
enum SavedKind {
  favourite('favourite'),
  watchlist('watchlist');

  const SavedKind(this.wireName);

  final String wireName;

  static SavedKind fromWire(String value) => SavedKind.values.firstWhere(
    (kind) => kind.wireName == value,
    orElse: () => SavedKind.favourite,
  );
}

/// A title saved in the favourites or the watchlist.
class LibraryEntry {
  const LibraryEntry({
    required this.kind,
    required this.provider,
    required this.subjectId,
    required this.title,
    required this.mediaType,
    this.posterUrl,
    this.year,
    this.releaseLabel,
    this.addedAt = 0,
  });

  final SavedKind kind;
  final ProviderKind provider;
  final String subjectId;
  final String title;
  final MediaType mediaType;
  final String? posterUrl;
  final String? year;
  final String? releaseLabel;
  final int addedAt;
}

/// Stores the favourites and the watchlist.
class LibraryRepository {
  LibraryRepository(this._db);

  final AppDatabase _db;

  /// Loads a saved list.
  Future<List<LibraryEntry>> list(SavedKind kind) async {
    final rows =
        await (_db.select(_db.savedTitles)
              ..where((row) => row.kind.equals(kind.wireName))
              ..orderBy([(row) => OrderingTerm.desc(row.addedAt)]))
            .get();
    return rows.map(_toModel).toList();
  }

  /// Watches a saved list.
  Stream<List<LibraryEntry>> watch(SavedKind kind) {
    final query = _db.select(_db.savedTitles)
      ..where((row) => row.kind.equals(kind.wireName))
      ..orderBy([(row) => OrderingTerm.desc(row.addedAt)]);
    return query.watch().map((rows) => rows.map(_toModel).toList());
  }

  /// True when the title is saved in the given list.
  Future<bool> contains(
    SavedKind kind,
    ProviderKind provider,
    String subjectId,
  ) async {
    final row =
        await (_db.select(_db.savedTitles)..where(
              (row) =>
                  row.kind.equals(kind.wireName) &
                  row.provider.equals(provider.cacheKey) &
                  row.subjectId.equals(subjectId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  /// Adds a title to a list.
  Future<void> add(LibraryEntry title) async {
    await _db.transaction(() async {
      await _db
          .into(_db.savedTitles)
          .insert(
            SavedTitlesCompanion.insert(
              kind: title.kind.wireName,
              provider: title.provider.cacheKey,
              subjectId: title.subjectId,
              title: title.title,
              posterUrl: Value(title.posterUrl),
              mediaType: title.mediaType.wireName,
              year: Value(title.year),
              releaseLabel: Value(title.releaseLabel),
              addedAt: DateTime.now().millisecondsSinceEpoch,
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  /// Removes a title from a list.
  Future<void> remove(
    SavedKind kind,
    ProviderKind provider,
    String subjectId,
  ) async {
    await (_db.delete(_db.savedTitles)..where(
          (row) =>
              row.kind.equals(kind.wireName) &
              row.provider.equals(provider.cacheKey) &
              row.subjectId.equals(subjectId),
        ))
        .go();
  }

  /// Adds the title when it is missing, removes it otherwise.
  Future<bool> toggle(LibraryEntry title) async {
    final exists = await contains(title.kind, title.provider, title.subjectId);
    if (exists) {
      await remove(title.kind, title.provider, title.subjectId);
      return false;
    }
    await add(title);
    return true;
  }

  /// Empties a list.
  Future<void> clear(SavedKind kind) async {
    await (_db.delete(
      _db.savedTitles,
    )..where((row) => row.kind.equals(kind.wireName))).go();
  }

  LibraryEntry _toModel(SavedTitle row) => LibraryEntry(
    kind: SavedKind.fromWire(row.kind),
    provider: ProviderKind.tryParse(row.provider) ?? ProviderKind.moviebox,
    subjectId: row.subjectId,
    title: row.title,
    mediaType: MediaType.fromWire(row.mediaType),
    posterUrl: row.posterUrl,
    year: row.year,
    releaseLabel: row.releaseLabel,
    addedAt: row.addedAt,
  );
}
