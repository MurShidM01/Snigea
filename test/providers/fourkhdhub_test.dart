import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/providers/fourkhdhub/fourkhdhub_parser.dart';
import 'package:snigea/data/models/release.dart';
import 'package:snigea/providers/fourkhdhub/hubcloud.dart';

const String _searchHtml = '''
<html><body>
  <a class="movie-card" href="/movie/inception-2010">
    <h3 class="movie-card-title">Inception</h3>
    <span class="movie-card-meta">2010 · 1080p</span>
    <img src="https://cdn.example.com/inception.jpg" />
  </a>
  <a class="movie-card" href="/movie/breaking-bad-series-2008">
    <h3 class="movie-card-title">Breaking Bad</h3>
    <span class="movie-card-meta">2008 · S5</span>
    <img src="https://cdn.example.com/bb.jpg" />
  </a>
</body></html>
''';

const String _detailsHtml = '''
<html><body>
  <h1>Interstellar (2014)</h1>
  <div class="movie-tagline">A team travels through a wormhole</div>
  <div class="imdb-score">8.7</div>
  <meta property="og:image" content="https://cdn.example.com/interstellar.jpg" />
  <div class="metadata-item">
    <span class="metadata-label">Release:</span>
    <span class="metadata-value">2014</span>
  </div>
  <div class="metadata-item">
    <span class="metadata-label">Director:</span>
    <span class="metadata-value">Christopher Nolan</span>
  </div>
  <div class="metadata-item">
    <span class="metadata-label">Stars:</span>
    <span class="metadata-value">Matthew McConaughey</span>
  </div>
  <div class="metadata-item">
    <span class="metadata-label">Audios:</span>
    <span class="metadata-value">English, Hindi</span>
  </div>
  <div class="badge-outline"><a href="#">Action</a><a href="#">Drama</a></div>
  <div class="content-section"><p class="mt-4">A team of explorers travel through a wormhole.</p></div>
  <div id="episodes">
    <div class="episode-download-item">
      <span class="episode-file-title">Interstellar.S01E01.1080p.BluRay.x264-GRP</span>
      <span class="badge-size">2.4 GB</span>
      <a href="https://hubcloud.ist/drive/abc">HubCloud</a>
      <a href="https://pixeldrain.dev/u/xyz">PixelDrain</a>
    </div>
    <div class="episode-download-item">
      <span class="episode-file-title">Interstellar.S01E02.1080p.BluRay.x264-GRP</span>
      <span class="badge-size">2.2 GB</span>
      <a href="https://hubcloud.ist/drive/def">HubCloud</a>
    </div>
  </div>
</body></html>
''';

void main() {
  group('FourKHdHubParser', () {
    test('parses the search results', () {
      final items = FourKHdHubParser.parseSearch(
        'https://4khdhub.one/',
        _searchHtml,
      );
      expect(items.length, 2);
      expect(items[0].title, 'Inception');
      expect(items[0].id.value, '/movie/inception-2010');
      expect(items[0].year, '2010');
      expect(items[0].posterUrl, 'https://cdn.example.com/inception.jpg');
      expect(items[1].mediaType.name, 'series');
      expect(items[1].seasonCount, 5);
    });

    test('parses the details page', () {
      final details = FourKHdHubParser.parseDetails(
        '/movie/interstellar-2014',
        _detailsHtml,
      );
      expect(details.title, 'Interstellar');
      expect(details.year, '2014');
      expect(details.director, 'Christopher Nolan');
      expect(details.stars, 'Matthew McConaughey');
      expect(details.imdbRating, '8.7');
      expect(details.tagline, 'A team travels through a wormhole');
      expect(details.genres, containsAll(['Action', 'Drama']));
      expect(details.posterUrl, 'https://cdn.example.com/interstellar.jpg');
      expect(details.description, isNotNull);
    });

    test('parses the episode rows', () {
      final releases = FourKHdHubParser.parseReleases(
        _detailsHtml,
        season: 1,
        episode: 1,
      );
      expect(releases.length, 1);
      expect(releases.first.quality, '1080p');
      expect(releases.first.codec, 'H.264');
      expect(releases.first.language, contains('Hindi'));
      expect(releases.first.season, 1);
      expect(releases.first.episode, 1);
      expect(releases.first.mirrors.length, 2);
      expect(releases.first.mirrors.any((mirror) => mirror.directFile), isTrue);
    });

    test('parses a season and episode marker', () {
      expect(FourKHdHubParser.parseSeasonEpisode('Show.S01E02.1080p'), (1, 2));
      expect(FourKHdHubParser.parseSeasonEpisode('no marker'), isNull);
    });

    test('detects the quality and the codec', () {
      expect(FourKHdHubParser.detectQuality('Movie.2160p.HDR.x265'), '2160p');
      expect(
        FourKHdHubParser.detectQuality('Show.S01E01.FHD.1080p.mkv'),
        '1080p',
      );
      expect(FourKHdHubParser.detectQuality('Unknown.Release'), isNull);
      expect(FourKHdHubParser.detectCodec('Movie.HEVC.mkv'), 'HEVC');
      expect(FourKHdHubParser.detectCodec('Movie.AV1.mkv'), 'AV1');
    });

    test('removes a trailing year', () {
      expect(
        FourKHdHubParser.stripTrailingYear('Movie Name (2024)'),
        'Movie Name',
      );
      expect(
        FourKHdHubParser.stripTrailingYear('Not A Year (20x4)'),
        'Not A Year (20x4)',
      );
    });
  });

  group('HubCloud', () {
    test('rejects insecure and private playback urls', () {
      expect(
        HubCloud.validatePlaybackUrl('http://insecure.com/file.mkv'),
        isNull,
      );
      expect(
        HubCloud.validatePlaybackUrl('https://localhost/file.mkv'),
        isNull,
      );
      expect(
        HubCloud.validatePlaybackUrl('https://127.0.0.1/file.mkv'),
        isNull,
      );
      expect(
        HubCloud.validatePlaybackUrl('https://192.168.1.100/file.mkv'),
        isNull,
      );
      expect(
        HubCloud.validatePlaybackUrl('https://example.com/archive.zip'),
        isNull,
      );
      expect(
        HubCloud.validatePlaybackUrl('https://example.com/login.php'),
        isNull,
      );
    });

    test('encodes the spaces of a playback url', () {
      final validated = HubCloud.validatePlaybackUrl(
        'https://cdn.example.com/0:/Game of Thrones/Game.of.Thrones.S01E01.mkv',
      );
      expect(validated, isNotNull);
      expect(validated, contains('Game%20of%20Thrones'));
    });

    test('scores the mirrors by priority', () {
      expect(
        HubCloud.score(
          'https://pixel.hubcloud.ist/?id=123',
          'Download [Server : 10Gbps]',
          ResolutionIntent.playback,
        ),
        0,
      );
      expect(
        HubCloud.score(
          'https://worker.sub.workers.dev/file.mkv',
          'Cloudflare',
          ResolutionIntent.playback,
        ),
        4,
      );
      expect(
        HubCloud.score(
          'https://c357acb6.r2.cloudflarestorage.com/file.mkv',
          'FSL Server',
          ResolutionIntent.playback,
        ),
        0,
      );
      expect(
        HubCloud.score(
          'https://pixeldrain.com/api/file/abc?download',
          'PixelDrain',
          ResolutionIntent.playback,
        ),
        2,
      );
    });

    test('converts a pixeldrain link into the api url', () {
      expect(
        HubCloud.pixeldrainApiUrl('https://pixeldrain.dev/u/abc'),
        'https://pixeldrain.dev/api/file/abc?download',
      );
      expect(HubCloud.pixeldrainApiUrl('https://example.com/u/abc'), isNull);
    });

    test('extracts the greenmotors payload', () {
      const snippet =
          "<script>function s(e,t,i){}s('o','TEST_PAYLOAD_ABC123',180000);</script>";
      expect(
        HubCloud.extractGreenmotorsPayload(snippet),
        'TEST_PAYLOAD_ABC123',
      );
    });
  });
}
