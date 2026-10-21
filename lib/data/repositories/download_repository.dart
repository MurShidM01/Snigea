import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/provider_kind.dart';
import '../database/app_database.dart';

/// The lifecycle state of a download.
enum DownloadStatus {
  queued('queued'),
  running('running'),
  paused('paused'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  const DownloadStatus(this.wireName);

  final String wireName;

  static DownloadStatus fromWire(String value) =>
      DownloadStatus.values.firstWhere(
        (status) => status.wireName == value,
        orElse: () => DownloadStatus.queued,
      );

  bool get isTerminal =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.failed ||
      this == DownloadStatus.cancelled;
}

/// A download task.
class DownloadTask {
  const DownloadTask({
    required this.provider,
    required this.subjectId,
    required this.title,
    required this.url,
    required this.fileName,
    required this.status,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.id,
    this.season = 0,
    this.episode = 0,
    this.headers = const [],
    this.posterUrl,
    this.filePath,
    this.totalBytes,
    this.downloadedBytes = 0,
    this.error,
    this.integrity,
  });

  final int? id;
  final ProviderKind provider;
  final String subjectId;
  final String title;
  final int season;
  final int episode;
  final String url;
  final List<MapEntry<String, String>> headers;
  final String fileName;

  /// The poster of the downloaded title.
  final String? posterUrl;
  final String? filePath;
  final int? totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final String? error;
  final String? integrity;
  final int createdAt;
  final int updatedAt;

  /// The progress in percent, or `null` when the size is unknown.
  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (downloadedBytes / total).clamp(0.0, 1.0);
  }
}

/// Stores the download tasks.
class DownloadRepository {
  DownloadRepository(this._db);

  final AppDatabase _db;

  /// Inserts a new download task.
  Future<int> insert(DownloadTask record) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db
        .into(_db.downloadRecords)
        .insert(
          DownloadRecordsCompanion.insert(
            provider: record.provider.cacheKey,
            subjectId: record.subjectId,
            title: record.title,
            season: Value(record.season),
            episode: Value(record.episode),
            url: record.url,
            headersJson: Value(jsonEncode(_encodeHeaders(record.headers))),
            fileName: record.fileName,
            posterUrl: Value(record.posterUrl),
            filePath: Value(record.filePath),
            totalBytes: Value(record.totalBytes),
            downloadedBytes: Value(record.downloadedBytes),
            status: record.status.wireName,
            error: Value(record.error),
            integrity: Value(record.integrity),
            createdAt: record.createdAt == 0 ? now : record.createdAt,
            updatedAt: now,
          ),
        );
  }

  /// Updates a download task.
  Future<void> update(DownloadTask record) async {
    final id = record.id;
    if (id == null) return;
    await (_db.update(
      _db.downloadRecords,
    )..where((row) => row.id.equals(id))).write(
      DownloadRecordsCompanion(
        downloadedBytes: Value(record.downloadedBytes),
        totalBytes: Value(record.totalBytes),
        status: Value(record.status.wireName),
        error: Value(record.error),
        filePath: Value(record.filePath),
        integrity: Value(record.integrity),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Loads every task, newest first.
  Future<List<DownloadTask>> all() async {
    final rows = await (_db.select(
      _db.downloadRecords,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
    return rows.map(_toModel).toList();
  }

  /// Watches every task, newest first.
  Stream<List<DownloadTask>> watchAll() {
    final query = _db.select(_db.downloadRecords)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch().map((rows) => rows.map(_toModel).toList());
  }

  /// Loads a single task.
  Future<DownloadTask?> byId(int id) async {
    final row = await (_db.select(
      _db.downloadRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  /// Removes a task.
  Future<void> remove(int id) async {
    await (_db.delete(
      _db.downloadRecords,
    )..where((row) => row.id.equals(id))).go();
  }

  /// Removes every finished task.
  Future<void> clearFinished() async {
    await (_db.delete(_db.downloadRecords)..where(
          (row) =>
              row.status.equals(DownloadStatus.completed.wireName) |
              row.status.equals(DownloadStatus.failed.wireName) |
              row.status.equals(DownloadStatus.cancelled.wireName),
        ))
        .go();
  }

  static List<Map<String, Object?>> _encodeHeaders(
    List<MapEntry<String, String>> headers,
  ) => headers
      .map(
        (entry) => <String, Object?>{'name': entry.key, 'value': entry.value},
      )
      .toList(growable: false);

  DownloadTask _toModel(DownloadRecord row) {
    List<MapEntry<String, String>> headers = const [];
    final raw = row.headersJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          headers = decoded
              .whereType<Map<String, Object?>>()
              .map(
                (map) => MapEntry(
                  map['name']?.toString() ?? '',
                  map['value']?.toString() ?? '',
                ),
              )
              .where((entry) => entry.key.isNotEmpty)
              .toList();
        }
      } on FormatException {
        headers = const [];
      }
    }
    return DownloadTask(
      id: row.id,
      provider: ProviderKind.tryParse(row.provider) ?? ProviderKind.moviebox,
      subjectId: row.subjectId,
      title: row.title,
      season: row.season,
      episode: row.episode,
      url: row.url,
      headers: headers,
      fileName: row.fileName,
      posterUrl: row.posterUrl,
      filePath: row.filePath,
      totalBytes: row.totalBytes,
      downloadedBytes: row.downloadedBytes,
      status: DownloadStatus.fromWire(row.status),
      error: row.error,
      integrity: row.integrity,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
