import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/data/models/app_settings.dart';
import 'package:snigea/data/models/provider_kind.dart';
import 'package:snigea/data/models/release.dart';
import 'package:snigea/services/playback_service.dart';

void main() {
  group('AppSettings', () {
    test('encodes and decodes the preferences', () {
      const settings = AppSettings(
        activeProvider: ProviderKind.dramachi,
        enabledProviders: {ProviderKind.moviebox, ProviderKind.dramachi},
        playbackSpeed: 1.5,
        subtitlesEnabled: false,
        autoPlayNextEpisode: false,
        preferHighestQuality: false,
        downloadDirectory: '/tmp/snigea',
      );

      final decoded = AppSettings.decode(settings.encode());
      expect(decoded.activeProvider, ProviderKind.dramachi);
      expect(decoded.enabledProviders, {
        ProviderKind.moviebox,
        ProviderKind.dramachi,
      });
      expect(decoded.playbackSpeed, 1.5);
      expect(decoded.subtitlesEnabled, isFalse);
      expect(decoded.autoPlayNextEpisode, isFalse);
      expect(decoded.preferHighestQuality, isFalse);
      expect(decoded.downloadDirectory, '/tmp/snigea');
    });

    test('falls back to the defaults for a broken payload', () {
      final decoded = AppSettings.decode('not json');
      expect(decoded.activeProvider, ProviderKind.moviebox);
      expect(decoded.playbackSpeed, 1.0);
    });

    test('copies the settings', () {
      const settings = AppSettings();
      final copy = settings.copyWith(playbackSpeed: 2.0);
      expect(copy.playbackSpeed, 2.0);
      expect(copy.activeProvider, settings.activeProvider);
    });
  });

  group('Release', () {
    test('derives the resolution', () {
      Release withQuality(String? quality) => Release(
        provider: ProviderKind.moviebox,
        filename: 'file.mkv',
        quality: quality,
      );

      expect(withQuality('4K').resolutionU64, 2160);
      expect(withQuality('uhd').resolutionU64, 2160);
      expect(withQuality('2160p').resolutionU64, 2160);
      expect(withQuality('1080p').resolutionU64, 1080);
      expect(withQuality(null).resolutionU64, 1080);
    });

    test('marks a multi resolution release', () {
      const release = Release(
        provider: ProviderKind.moviebox,
        filename: 'file.mkv',
        quality: 'multi',
      );
      expect(release.isMultiResolution, isTrue);
      expect(release.resolutionI64, -1);
    });

    test('returns the first mirror url', () {
      const release = Release(
        provider: ProviderKind.moviebox,
        filename: 'file.mkv',
        mirrors: [
          SourceMirror(label: 'Direct', resolverUrl: 'https://example.com/a'),
          SourceMirror(label: 'Mirror', resolverUrl: 'https://example.com/b'),
        ],
      );
      expect(release.directUrl, 'https://example.com/a');
      expect(release.sourceLabel, 'Direct');
    });
  });

  group('PlaybackService', () {
    test('resolves a direct release', () async {
      final service = PlaybackService();
      const release = Release(
        provider: ProviderKind.moviebox,
        filename: 'file.mkv',
        mirrors: [
          SourceMirror(
            label: '1080p H265',
            resolverUrl: 'https://cdn.example.com/index.mpd',
            headers: [MapEntry('Cookie', 'CloudFront-Policy=abc')],
          ),
        ],
      );

      final source = await service.resolve(release);
      expect(source.url, 'https://cdn.example.com/index.mpd');
      expect(source.headers.length, 1);
      expect(source.sourceLabel, '1080p H265');
    });

    test('resolves an addon release', () async {
      final service = PlaybackService();
      const release = Release(
        provider: ProviderKind.addons,
        filename: 'Movie 1080p',
        mirrors: [
          SourceMirror(
            label: 'Addon · Host',
            resolverUrl: 'https://cdn.example.com/movie.mkv',
          ),
        ],
      );

      final source = await service.resolve(release);
      expect(source.provider, ProviderKind.addons);
      expect(source.sourceLabel, 'Addon · Host');
    });

    test('fails when a release has no source', () async {
      final service = PlaybackService();
      const release = Release(
        provider: ProviderKind.moviebox,
        filename: 'file.mkv',
      );
      expect(
        () => service.resolve(release),
        throwsA(isA<PlaybackResolutionException>()),
      );
    });
  });

  group('MovieBoxSubtitles', () {
    test('parses the caption payload', () {
      final options = MovieBoxSubtitles.parse({
        'data': {
          'extCaptions': [
            {
              'lan': 'en',
              'lanName': 'English',
              'size': '1000',
              'url': 'https://example.com/en.srt',
            },
            {
              'lan': 'en',
              'lanName': 'English',
              'size': '1000',
              'url': 'https://example.com/en.srt',
            },
          ],
        },
      });
      expect(options.length, 1);
      expect(options.first.name, 'English');
    });
  });
}
