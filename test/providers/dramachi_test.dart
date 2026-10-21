import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/providers/dramachi/dramachi_parser.dart';

void main() {
  group('DramachiParser', () {
    test('parses a search response', () {
      final payload = {
        'data': [
          {
            'id': 'abc',
            'title': 'Queen of Tears',
            'thumb': 'poster.jpg',
            'year': '2024',
            'content': 'series',
          },
          {
            'id': 'def',
            'title': 'Parasite',
            'thumb': '',
            'year': '2019',
            'content': 'movies',
          },
        ],
      };

      final items = DramachiParser.searchToCatalog(payload);
      expect(items.length, 2);
      expect(items[0].id.value, 'abc');
      expect(items[0].mediaType.name, 'series');
      expect(
        items[0].posterUrl,
        'https://static.nodeobjects.com/thumbnail/poster.jpg',
      );
      expect(items[1].mediaType.name, 'movie');
      expect(items[1].posterUrl, isNull);
    });

    test('parses the episode number of a title', () {
      expect(DramachiParser.parseEpisodeNumber('Queen of Tears S01E16'), 16);
      expect(DramachiParser.parseEpisodeNumber('Squid Game S02E07 DUB'), 7);
      expect(DramachiParser.parseEpisodeNumber('Parasite 2019 001'), 1);
      expect(DramachiParser.parseEpisodeNumber('The Mentalist S07E12'), 12);
    });

    test('extracts the season number of a key', () {
      expect(DramachiParser.extractLeadingSeasonNumber('Season 01'), 1);
      expect(DramachiParser.extractLeadingSeasonNumber('Season 2'), 2);
      expect(DramachiParser.extractLeadingSeasonNumber('hd Rip'), isNull);
    });

    test('cleans the quality suffixes of an episode title', () {
      expect(
        DramachiParser.cleanEpisodeTitle('Queen of Tears S01E16 1080p'),
        'Queen of Tears S01E16',
      );
    });

    test('builds a release with the CDN mirror', () {
      final release = DramachiParser.toRelease(
        filename: 'episode.mkv',
        url: 'https://cdn.dramachi.com/cdn/episode.mkv',
        quality: '1080p',
        size: '218.32 MB',
        season: 1,
        episode: 2,
        resourceId: 'fid-1',
      );
      expect(release.provider.cacheKey, 'dramachi');
      expect(release.sizeBytes, 228925112);
      expect(release.mirrors.first.label, 'Dramachi CDN');
      expect(release.mirrors.first.directFile, isTrue);
      expect(release.resourceId, 'fid-1');
    });
  });
}
