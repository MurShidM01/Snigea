import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/provider_kind.dart';
import '../database/app_database.dart';

/// A previously issued search query.
class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.query,
    required this.provider,
    required this.searchedAt,
    this.resultCount = 0,
  });

  final String query;
  final ProviderKind provider;
  final int searchedAt;
  final int resultCount;
}

/// Stores the search history.
class SearchHistoryRepository {
  SearchHistoryRepository(this._db);

  final AppDatabase _db;

  /// Records a search.
  Future<void> record(
    String query,
    ProviderKind provider, {
    int resultCount = 0,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _db
          .into(_db.searchHistory)
          .insert(
            SearchHistoryCompanion.insert(
              query: trimmed,
              provider: provider.cacheKey,
              resultCount: Value(resultCount),
              searchedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );
      // Keep the history small.
      final all = await _db.select(_db.searchHistory).get();
      if (all.length > 40) {
        final sorted = all
          ..sort((a, b) => a.searchedAt.compareTo(b.searchedAt));
        final excess = sorted.take(all.length - 40).toList();
        await (_db.delete(
          _db.searchHistory,
        )..where((row) => row.id.isIn(excess.map((e) => e.id)))).go();
      }
    });
  }

  /// The most recent searches.
  Future<List<SearchHistoryEntry>> recent({int limit = 12}) async {
    final rows =
        await (_db.select(_db.searchHistory)
              ..orderBy([(row) => OrderingTerm.desc(row.searchedAt)])
              ..limit(limit))
            .get();
    return rows
        .map(
          (row) => SearchHistoryEntry(
            query: row.query,
            provider:
                ProviderKind.tryParse(row.provider) ?? ProviderKind.moviebox,
            searchedAt: row.searchedAt,
            resultCount: row.resultCount,
          ),
        )
        .toList();
  }

  /// Removes a single entry.
  Future<void> remove(String query) async {
    await (_db.delete(
      _db.searchHistory,
    )..where((row) => row.query.equals(query))).go();
  }

  /// Removes every entry.
  Future<void> clear() async {
    await _db.delete(_db.searchHistory).go();
  }
}

/// A user preference stored as a key/value pair.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// Reads a value.
  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Writes a value.
  Future<void> write(String key, String value) async {
    await _db
        .into(_db.settings)
        .insert(
          SettingsCompanion.insert(key: key, value: value),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Reads a boolean value.
  Future<bool> readBool(String key, {bool fallback = false}) async {
    final value = await read(key);
    if (value == null) return fallback;
    return value == 'true';
  }

  /// Writes a boolean value.
  Future<void> writeBool(String key, bool value) =>
      write(key, value ? 'true' : 'false');

  /// Reads an integer value.
  Future<int?> readInt(String key) async {
    final value = await read(key);
    return value == null ? null : int.tryParse(value);
  }

  /// Writes an integer value.
  Future<void> writeInt(String key, int value) => write(key, '$value');

  /// Removes a value.
  Future<void> remove(String key) async {
    await (_db.delete(_db.settings)..where((row) => row.key.equals(key))).go();
  }
}

/// The persisted configuration of a provider.
class ProviderSettings {
  const ProviderSettings({
    required this.provider,
    this.enabled = true,
    this.baseUrl,
    this.extra,
  });

  final ProviderKind provider;
  final bool enabled;
  final String? baseUrl;
  final String? extra;

  Map<String, Object?> toJson() => {
    'provider': provider.cacheKey,
    'enabled': enabled,
    'baseUrl': baseUrl,
    'extra': extra,
  };
}

/// Stores the per provider configuration.
class ProviderConfigRepository {
  ProviderConfigRepository(this._db);

  final AppDatabase _db;

  /// Loads every configuration, filling in the defaults.
  Future<Map<ProviderKind, ProviderSettings>> all() async {
    final rows = await _db.select(_db.providerConfigs).get();
    final map = <ProviderKind, ProviderSettings>{};
    for (final provider in ProviderKind.values) {
      map[provider] = ProviderSettings(provider: provider);
    }
    for (final row in rows) {
      final provider = ProviderKind.tryParse(row.provider);
      if (provider == null) continue;
      map[provider] = ProviderSettings(
        provider: provider,
        enabled: row.enabled,
        baseUrl: row.baseUrl,
        extra: row.extra,
      );
    }
    return map;
  }

  /// Saves a configuration.
  Future<void> save(ProviderSettings config) async {
    await _db
        .into(_db.providerConfigs)
        .insert(
          ProviderConfigsCompanion.insert(
            provider: config.provider.cacheKey,
            enabled: Value(config.enabled),
            baseUrl: Value(config.baseUrl),
            extra: Value(config.extra),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Removes a configuration, restoring the default.
  Future<void> remove(ProviderKind provider) async {
    await (_db.delete(
      _db.providerConfigs,
    )..where((row) => row.provider.equals(provider.cacheKey))).go();
  }
}

/// A cached metadata payload.
class CachedMetadata {
  const CachedMetadata({
    required this.cacheKey,
    required this.provider,
    required this.subjectId,
    required this.payload,
    required this.fetchedAt,
    required this.expiresAt,
  });

  final String cacheKey;
  final ProviderKind provider;
  final String subjectId;
  final String payload;
  final int fetchedAt;
  final int expiresAt;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;
}

/// Stores cached provider responses.
class MetadataCacheRepository {
  MetadataCacheRepository(this._db);

  final AppDatabase _db;

  /// Reads a cached payload.
  Future<CachedMetadata?> read(String cacheKey) async {
    final row = await (_db.select(
      _db.metadataCacheEntries,
    )..where((row) => row.cacheKey.equals(cacheKey))).getSingleOrNull();
    if (row == null) return null;
    final entry = CachedMetadata(
      cacheKey: row.cacheKey,
      provider: ProviderKind.tryParse(row.provider) ?? ProviderKind.moviebox,
      subjectId: row.subjectId,
      payload: row.payload,
      fetchedAt: row.fetchedAt,
      expiresAt: row.expiresAt,
    );
    if (entry.isExpired) {
      await remove(cacheKey);
      return null;
    }
    return entry;
  }

  /// Reads and decodes a cached JSON payload.
  Future<Object?> readJson(String cacheKey) async {
    final entry = await read(cacheKey);
    if (entry == null) return null;
    try {
      return jsonDecode(entry.payload);
    } on FormatException {
      return null;
    }
  }

  /// Writes a cached payload.
  Future<void> write({
    required String cacheKey,
    required ProviderKind provider,
    required String subjectId,
    required Object payload,
    Duration ttl = const Duration(hours: 24),
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.metadataCacheEntries)
        .insert(
          MetadataCacheEntriesCompanion.insert(
            cacheKey: cacheKey,
            provider: provider.cacheKey,
            subjectId: subjectId,
            payload: jsonEncode(payload),
            fetchedAt: now,
            expiresAt: now + ttl.inMilliseconds,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Removes a cached payload.
  Future<void> remove(String cacheKey) async {
    await (_db.delete(
      _db.metadataCacheEntries,
    )..where((row) => row.cacheKey.equals(cacheKey))).go();
  }

  /// Removes every expired entry.
  Future<void> prune() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.delete(
      _db.metadataCacheEntries,
    )..where((row) => row.expiresAt.isSmallerThanValue(now))).go();
  }
}
