import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/providers/addons/addon_adapter.dart';
import 'package:snigea/providers/addons/addon_client.dart';
import 'package:snigea/providers/addons/addon_models.dart';

void main() {
  group('AddonClient', () {
    test('normalises the manifest url', () {
      expect(
        AddonClient.normalizeManifestUrl('stremio://example.com/addon'),
        'https://example.com/addon/manifest.json',
      );
      expect(
        AddonClient.normalizeManifestUrl('https://example.com/manifest.json'),
        'https://example.com/manifest.json',
      );
      expect(
        AddonClient.normalizeManifestUrl('https://example.com/'),
        'https://example.com/manifest.json',
      );
    });

    test('derives the base url', () {
      expect(
        AddonClient.baseAddonUrl('https://example.com/manifest.json'),
        'https://example.com',
      );
    });
  });

  group('AddonAdapter', () {
    test('converts a catalogue entry', () {
      final item = MetaItem.fromJson({
        'id': 'tt1234567',
        'type': 'series',
        'name': 'Severance',
        'releaseInfo': '2022-2023',
        'poster': 'https://images.example.com/poster.jpg',
      });
      final catalogItem = AddonAdapter.metaToCatalogItem(item);
      expect(catalogItem.id.value, 'series:tt1234567');
      expect(catalogItem.title, 'Severance');
      expect(catalogItem.year, '2022');
      expect(catalogItem.mediaType.name, 'series');
    });

    test('converts the metadata of a series', () {
      final detail = MetaDetail.fromJson({
        'id': 'tt1234567',
        'type': 'series',
        'name': 'Severance',
        'releaseInfo': '2022',
        'description': 'A workplace thriller.',
        'imdbRating': '8.7',
        'genres': ['Drama', 'Mystery'],
        'cast': ['Adam Scott'],
        'videos': [
          {'season': 1, 'episode': 1, 'title': 'Good News About Hell'},
          {'season': 1, 'episode': 2, 'title': 'Half Loop'},
          {'season': 2, 'episode': 1, 'title': 'Hello, Ms. Cobel'},
        ],
      });

      final details = AddonAdapter.metaDetailToMediaDetails(detail);
      expect(details.id.value, 'series:tt1234567');
      expect(details.seasons.length, 2);
      expect(details.seasons.first.episodes.length, 2);
      expect(
        details.seasons.first.episodes.first.title,
        'Good News About Hell',
      );
      expect(details.imdbRating, '8.7');
      expect(details.stars, 'Adam Scott');
      expect(details.genres, ['Drama', 'Mystery']);
    });

    test('detects the quality, the codec and the audio tracks', () {
      expect(AddonAdapter.parseQuality('Movie 2160p'), '2160p');
      expect(AddonAdapter.parseQuality('Movie 1080p FHD'), '1080p');
      expect(AddonAdapter.parseQuality('Movie 720p'), '720p');
      expect(AddonAdapter.parseQuality('Movie'), isNull);

      expect(AddonAdapter.parseCodec('Movie HEVC'), 'HEVC/x265');
      expect(AddonAdapter.parseCodec('Movie x264'), 'AVC/x264');
      expect(AddonAdapter.parseCodec('Movie AV1'), 'AV1');

      expect(
        AddonAdapter.parseAudioTracks('Movie Hindi English'),
        'Hindi + English',
      );
    });

    test('parses a season and episode marker', () {
      expect(AddonAdapter.parseSeasonEpisode('Show S01E02'), (1, 2));
      expect(AddonAdapter.parseSeasonEpisode('Show 1x02'), (1, 2));
      expect(AddonAdapter.parseSeasonEpisode('SEASON 2 EPISODE 5'), (2, 5));
      expect(AddonAdapter.parseSeasonEpisode('EPISODE 7'), (1, 7));
    });

    test('derives a readable source label', () {
      expect(
        AddonAdapter.detectStreamHost(
          addonName: 'Addon',
          streamName: 'Addon\n1080p',
          url: 'https://sbcdn3.hakunaymatata.com/file.mkv',
        ),
        'Addon · 1080p',
      );
      expect(
        AddonAdapter.extractDomainLabel('https://sbcdn3.hakunaymatata.com/x'),
        'Hakunaymatata',
      );
    });

    test('converts a stream into a release', () {
      final stream = StreamItem.fromJson({
        'name': 'Addon 1080p',
        'title': 'Movie.1080p.Hindi.mkv',
        'url': 'https://cdn.example.com/movie.mkv',
        'behaviorHints': {
          'videoSize': 1234,
          'headers': {'Referer': 'https://example.com', 'X-Custom': 'blocked'},
        },
      });

      final release = AddonAdapter.streamItemToRelease(
        'Addon',
        stream,
        season: 0,
        episode: 0,
      );
      expect(release, isNotNull);
      expect(release!.quality, '1080p');
      expect(release.language, 'Hindi');
      expect(release.sizeBytes, 1234);
      expect(
        release.mirrors.first.resolverUrl,
        'https://cdn.example.com/movie.mkv',
      );
      expect(release.mirrors.first.headers.length, 1);
      expect(release.mirrors.first.headers.first.key, 'Referer');
    });

    test('rejects a non http stream', () {
      final stream = StreamItem.fromJson({
        'name': 'Torrent',
        'infoHash': '0123456789',
      });
      expect(
        AddonAdapter.streamItemToRelease(
          'Addon',
          stream,
          season: 0,
          episode: 0,
        ),
        isNull,
      );
    });

    test('filters a stream of another episode', () {
      final stream = StreamItem.fromJson({
        'name': 'Show S01E03',
        'url': 'https://cdn.example.com/episode.mkv',
      });
      expect(
        AddonAdapter.streamItemToRelease(
          'Addon',
          stream,
          season: 1,
          episode: 2,
        ),
        isNull,
      );
    });
  });
}
