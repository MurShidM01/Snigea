import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/data/database/app_database.dart';
import 'package:snigea/data/models/media.dart';
import 'package:snigea/data/models/provider_kind.dart';
import 'package:snigea/data/repositories/download_repository.dart';
import 'package:snigea/data/repositories/library_repository.dart';
import 'package:snigea/data/repositories/progress_repository.dart';
import 'package:snigea/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('LibraryRepository', () {
    test('adds, lists and removes a favourite', () async {
      final repository = LibraryRepository(database);

      const entry = LibraryEntry(
        kind: SavedKind.favourite,
        provider: ProviderKind.moviebox,
        subjectId: '12345',
        title: 'Inception',
        mediaType: MediaType.movie,
        year: '2010',
      );

      await repository.add(entry);
      final favourites = await repository.list(SavedKind.favourite);
      expect(favourites.length, 1);
      expect(favourites.first.title, 'Inception');
      expect(favourites.first.provider, ProviderKind.moviebox);

      final watchlist = await repository.list(SavedKind.watchlist);
      expect(watchlist, isEmpty);

      expect(
        await repository.contains(
          SavedKind.favourite,
          ProviderKind.moviebox,
          '12345',
        ),
        isTrue,
      );

      await repository.remove(
        SavedKind.favourite,
        ProviderKind.moviebox,
        '12345',
      );
      expect(await repository.list(SavedKind.favourite), isEmpty);
    });

    test('toggles a title', () async {
      final repository = LibraryRepository(database);
      const entry = LibraryEntry(
        kind: SavedKind.watchlist,
        provider: ProviderKind.dramachi,
        subjectId: 'abc',
        title: 'Drama',
        mediaType: MediaType.series,
      );

      expect(await repository.toggle(entry), isTrue);
      expect(await repository.list(SavedKind.watchlist), hasLength(1));
      expect(await repository.toggle(entry), isFalse);
      expect(await repository.list(SavedKind.watchlist), isEmpty);
    });

    test('does not duplicate a title', () async {
      final repository = LibraryRepository(database);
      const entry = LibraryEntry(
        kind: SavedKind.favourite,
        provider: ProviderKind.moviebox,
        subjectId: '1',
        title: 'One',
        mediaType: MediaType.movie,
      );
      await repository.add(entry);
      await repository.add(entry);
      expect(await repository.list(SavedKind.favourite), hasLength(1));
    });
  });

  group('ProgressRepository', () {
    test('stores and restores the playback position', () async {
      final repository = ProgressRepository(database);

      await repository.save(
        ProgressEntry(
          provider: ProviderKind.moviebox,
          subjectId: '12345',
          title: 'Inception',
          mediaType: MediaType.movie,
          season: 0,
          episode: 0,
          positionMs: 60000,
          durationMs: 600000,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final entry = await repository.entry(ProviderKind.moviebox, '12345');
      expect(entry, isNotNull);
      expect(entry!.positionMs, 60000);
      expect(entry.fraction, closeTo(0.1, 0.001));
      expect(entry.isResumable, isTrue);
    });

    test('does not offer a finished title for resuming', () async {
      final repository = ProgressRepository(database);
      await repository.save(
        ProgressEntry(
          provider: ProviderKind.moviebox,
          subjectId: '1',
          title: 'Done',
          mediaType: MediaType.movie,
          positionMs: 590000,
          durationMs: 600000,
          completed: true,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      final entry = await repository.entry(ProviderKind.moviebox, '1');
      expect(entry!.isResumable, isFalse);
      expect(await repository.continueWatching(), isEmpty);
    });

    test('does not resume a barely started title', () async {
      final repository = ProgressRepository(database);
      await repository.save(
        ProgressEntry(
          provider: ProviderKind.moviebox,
          subjectId: '2',
          title: 'Started',
          mediaType: MediaType.movie,
          positionMs: 5000,
          durationMs: 600000,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      final entry = await repository.entry(ProviderKind.moviebox, '2');
      expect(entry!.isResumable, isFalse);
    });

    test('records the watched episodes', () async {
      final repository = ProgressRepository(database);
      await repository.markWatched(
        provider: ProviderKind.dramachi,
        subjectId: 'abc',
        title: 'Drama',
        season: 1,
        episode: 2,
      );
      expect(
        await repository.isWatched(ProviderKind.dramachi, 'abc', 1, 2),
        isTrue,
      );
      expect(
        await repository.isWatched(ProviderKind.dramachi, 'abc', 1, 3),
        isFalse,
      );
      final watched = await repository.watchedEpisodeNumbers(
        ProviderKind.dramachi,
        'abc',
      );
      expect(watched, {2});
    });

    test('lists the continue watching entries', () async {
      final repository = ProgressRepository(database);
      for (var index = 0; index < 3; index++) {
        await repository.save(
          ProgressEntry(
            provider: ProviderKind.moviebox,
            subjectId: '$index',
            title: 'Title $index',
            mediaType: MediaType.movie,
            positionMs: 60000,
            durationMs: 600000,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      final entries = await repository.continueWatching();
      expect(entries.length, 3);
      expect(entries.every((entry) => entry.isResumable), isTrue);
    });
  });

  group('SettingsRepository', () {
    test('stores and restores values', () async {
      final repository = SettingsRepository(database);
      expect(await repository.read('missing'), isNull);
      await repository.write('key', 'value');
      expect(await repository.read('key'), 'value');
      await repository.writeBool('flag', true);
      expect(await repository.readBool('flag'), isTrue);
      await repository.writeInt('count', 42);
      expect(await repository.readInt('count'), 42);
      await repository.remove('key');
      expect(await repository.read('key'), isNull);
    });
  });

  group('ProviderConfigRepository', () {
    test('stores the provider configuration', () async {
      final repository = ProviderConfigRepository(database);
      final defaults = await repository.all();
      expect(defaults.length, ProviderKind.values.length);
      expect(defaults[ProviderKind.moviebox]!.enabled, isTrue);

      await repository.save(
        const ProviderSettings(
          provider: ProviderKind.bdixCircleFtp,
          enabled: false,
          baseUrl: 'http://example.com',
        ),
      );
      final configs = await repository.all();
      expect(configs[ProviderKind.bdixCircleFtp]!.enabled, isFalse);
      expect(
        configs[ProviderKind.bdixCircleFtp]!.baseUrl,
        'http://example.com',
      );
    });
  });

  group('MetadataCacheRepository', () {
    test('stores, reads and expires a payload', () async {
      final repository = MetadataCacheRepository(database);
      await repository.write(
        cacheKey: 'details:moviebox:1',
        provider: ProviderKind.moviebox,
        subjectId: '1',
        payload: {'title': 'Inception'},
        ttl: const Duration(hours: 1),
      );

      final cached = await repository.readJson('details:moviebox:1');
      expect(cached, isA<Map>());
      expect((cached! as Map)['title'], 'Inception');

      await repository.write(
        cacheKey: 'expired',
        provider: ProviderKind.moviebox,
        subjectId: '1',
        payload: {'title': 'Old'},
        ttl: const Duration(seconds: -1),
      );
      expect(await repository.readJson('expired'), isNull);
    });
  });

  group('DownloadRepository', () {
    test('stores and updates a download task', () async {
      final repository = DownloadRepository(database);
      final id = await repository.insert(
        DownloadTask(
          provider: ProviderKind.moviebox,
          subjectId: '1',
          title: 'Movie',
          url: 'https://example.com/file.mkv',
          fileName: 'Movie.mkv',
          status: DownloadStatus.queued,
          headers: const [MapEntry('Referer', 'https://example.com')],
        ),
      );

      var tasks = await repository.all();
      expect(tasks.length, 1);
      expect(tasks.first.status, DownloadStatus.queued);
      expect(tasks.first.headers.first.key, 'Referer');

      await repository.update(
        DownloadTask(
          id: id,
          provider: ProviderKind.moviebox,
          subjectId: '1',
          title: 'Movie',
          url: 'https://example.com/file.mkv',
          fileName: 'Movie.mkv',
          filePath: 'Downloads/Movie.mkv',
          totalBytes: 1000,
          downloadedBytes: 1000,
          status: DownloadStatus.completed,
        ),
      );

      tasks = await repository.all();
      expect(tasks.first.status, DownloadStatus.completed);
      expect(tasks.first.fraction, 1);
    });

    test('clears the finished tasks', () async {
      final repository = DownloadRepository(database);
      await repository.insert(
        DownloadTask(
          provider: ProviderKind.moviebox,
          subjectId: '1',
          title: 'Movie',
          url: 'https://example.com/file.mkv',
          fileName: 'Movie.mkv',
          status: DownloadStatus.completed,
        ),
      );
      await repository.clearFinished();
      expect(await repository.all(), isEmpty);
    });
  });

  group('SearchHistoryRepository', () {
    test('records and removes the search history', () async {
      final repository = SearchHistoryRepository(database);
      await repository.record(
        'Inception',
        ProviderKind.moviebox,
        resultCount: 3,
      );
      await repository.record('Dune', ProviderKind.moviebox, resultCount: 1);

      final entries = await repository.recent();
      expect(entries.length, 2);
      expect(entries.first.query, 'Dune');

      await repository.remove('Dune');
      expect(await repository.recent(), hasLength(1));

      await repository.clear();
      expect(await repository.recent(), isEmpty);
    });
  });
}
