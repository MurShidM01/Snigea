import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/data/models/provider_kind.dart';
import 'package:snigea/data/models/release.dart';
import 'package:snigea/providers/moviebox/moviebox_client.dart';
import 'package:snigea/providers/moviebox/moviebox_parser.dart';

/// A payload captured from the live subject-details endpoint, trimmed to the
/// fields the parser reads.
Map<String, Object?> detectorPayload() => {
  'code': 0,
  'data': {
    'subjectId': '1511967966181605720',
    'title': 'Dune [Hindi]',
    'resourceDetectors': [
      {
        'codecName': 'hevc',
        'downloadUrl':
            'https://bcdn.hakunaymatata.com/resource/h265/b4fec.mp4?sign=a&t=1',
        'extCaptions': <Object?>[],
        'firstSize': '537628837',
        'postId': '6727829091426730920',
        'resourceId': '4625404299126915080',
        'resourceLink': 'https://vegamovies.pet/c33e/Dune-480P-h265',
        'source': 'vegamovies.pet',
        'subjectId': '1511967966181605720',
        'totalEpisode': 1,
        'totalSize': '2361181950',
        'type': 0,
        'uploadBy': 'adilessa',
        'uploadTime': '1723618507',
        'resolutionList': [
          {
            'codecName': 'hevc',
            'duration': 9325,
            'ep': 0,
            'episode': 0,
            'extCaptions': <Object?>[],
            'linkType': 2,
            'postId': '6727829091426730920',
            'requireMemberType': 0,
            'resolution': 480,
            'resourceId': '4625404299126915080',
            'resourceLink': 'https://bcdn.hakunaymatata.com/resource/h265/b4fec.mp4?sign=a&t=1',
            'se': 0,
            'size': '537628837',
            'sourceUrl': 'https://vegamovies.pet/c33e/Dune-480P-h265',
            'title': 'Dune',
            'uploadBy': 'adilessa',
          },
          {
            'codecName': 'h264',
            'duration': 9324,
            'ep': 0,
            'episode': 0,
            'extCaptions': <Object?>[],
            'linkType': 2,
            'postId': '4858807051218236672',
            'requireMemberType': 0,
            'resolution': 1080,
            'resourceId': '5764199508657799296',
            'resourceLink':
                'https://bcdn.hakunaymatata.com/tran-audio/e9a9.mp4?sign=b&t=2',
            'se': 0,
            'size': '1823553113',
            'sourceUrl': 'https://vegamovies.pet/edf3/Dune-1080P-tran-audio',
            'title': 'Dune [Hindi]-1080P',
            'uploadBy': 'adilessa',
          },
        ],
      },
    ],
  },
};

void main() {
  group('detectorJsonToReleases', () {
    test('parses the signed CDN links, highest resolution first', () {
      final releases = MovieBoxParser.detectorJsonToReleases(
        detectorPayload(),
        season: 0,
        episode: 0,
        userAgent: 'TestAgent/1.0',
      );

      expect(releases.length, 2);
      expect(releases.first.quality, '1080p');
      expect(releases.last.quality, '480p');
      expect(releases.first.codec, 'h264');
      expect(releases.first.sizeBytes, 1823553113);
      expect(releases.last.sizeBytes, 537628837);
      expect(releases.first.filename, 'Dune [Hindi]-1080P');
      expect(releases.first.resourceId, '5764199508657799296');

      final mirror = releases.first.mirrors.first;
      expect(mirror.directFile, isTrue);
      expect(mirror.label, 'adilessa');
      expect(mirror.resolverUrl, startsWith('https://bcdn.hakunaymatata.com/'));
      expect(mirror.resolverUrl, contains('sign='));
      // The CDN expects the app user agent and rejects a Referer header.
      expect(mirror.headers.length, 1);
      expect(mirror.headers.first.key, 'User-Agent');
      expect(mirror.headers.first.value, 'TestAgent/1.0');
    });

    test('skips the placeholder trailer', () {
      final payload = detectorPayload();
      final detectors =
          ((payload['data']! as Map<String, Object?>)['resourceDetectors']!
              as List<Object?>);
      final detector = detectors.first! as Map<String, Object?>;
      detector['resolutionList'] = [
        {
          'codecName': 'hevc',
          'duration': 23,
          'ep': 0,
          'resolution': 480,
          'size': '824720',
          'resourceId': '4625404299126915080',
          'resourceLink':
              'https://macdn.aoneroom.com/other/2026/10/10/80da52722.mp4',
          'se': 0,
          'title': 'Dune',
          'uploadBy': 'adilessa',
        },
      ];

      final releases = MovieBoxParser.detectorJsonToReleases(
        payload,
        season: 0,
        episode: 0,
        userAgent: 'TestAgent/1.0',
      );
      expect(
        releases,
        isEmpty,
        reason: 'the site trailer must never become a playable release',
      );
    });

    test('filters the requested episode', () {
      final payload = detectorPayload();
      final detectors =
          ((payload['data']! as Map<String, Object?>)['resourceDetectors']!
              as List<Object?>);
      final detector = detectors.first! as Map<String, Object?>;
      detector['resolutionList'] = [
        {
          'codecName': 'h264',
          'duration': 3000,
          'ep': 1,
          'resolution': 1080,
          'size': '900000000',
          'resourceId': '111',
          'resourceLink': 'https://bcdn.hakunaymatata.com/ep1.mp4?sign=a&t=1',
          'se': 1,
          'title': 'Episode 1',
          'uploadBy': 'uploader',
        },
        {
          'codecName': 'h264',
          'duration': 3000,
          'ep': 2,
          'resolution': 1080,
          'size': '800000000',
          'resourceId': '222',
          'resourceLink': 'https://bcdn.hakunaymatata.com/ep2.mp4?sign=b&t=1',
          'se': 1,
          'title': 'Episode 2',
          'uploadBy': 'uploader',
        },
      ];

      final releases = MovieBoxParser.detectorJsonToReleases(
        payload,
        season: 1,
        episode: 2,
        userAgent: 'TestAgent/1.0',
      );
      expect(releases.length, 1);
      expect(releases.first.filename, 'Episode 2');
      expect(releases.first.episode, 2);
      expect(releases.first.season, 1);
    });

    test('ignores detectors without links', () {
      final payload = {
        'code': 0,
        'data': {
          'resourceDetectors': [
            {
              'codecName': '',
              'downloadUrl': '',
              'postId': '3639848841740012888',
              'resolutionList': <Object?>[],
              'resourceId': '5369231098650281824',
              'resourceLink': 'https://kickasstorrents.to//059108/season-1',
              'source': 'kickasstorrents.to etc.',
              'totalEpisode': 3,
            },
          ],
        },
      };

      final releases = MovieBoxParser.detectorJsonToReleases(
        payload,
        season: 1,
        episode: 1,
        userAgent: 'TestAgent/1.0',
      );
      expect(
        releases,
        isEmpty,
        reason: 'an unresolved detector must not produce a release',
      );
    });
  });

  group('isTrailerOrNoticeUrl', () {
    test('recognises the placeholder clip', () {
      expect(
        MovieBoxParser.isTrailerOrNoticeUrl(
          'https://macdn.aoneroom.com/other/2026/10/10/80da52722.mp4',
        ),
        isTrue,
      );
      expect(
        MovieBoxParser.isTrailerOrNoticeUrl(
          'https://macdn.aoneroom.com/other/2026/09/01/9a0461bc.mp4',
        ),
        isTrue,
      );
      expect(
        MovieBoxParser.isTrailerOrNoticeUrl('https://example.com/notice.mp4'),
        isTrue,
      );
    });

    test('accepts the real media links', () {
      expect(
        MovieBoxParser.isTrailerOrNoticeUrl(
          'https://bcdn.hakunaymatata.com/resource/h265/b4fec.mp4?sign=a&t=1',
        ),
        isFalse,
      );
      expect(
        MovieBoxParser.isTrailerOrNoticeUrl(
          'https://cdn.example.com/movie.mkv',
        ),
        isFalse,
      );
    });

    test('keeps the legacy alias working', () {
      const url = 'https://macdn.aoneroom.com/other/2026/10/10/80da52722.mp4';
      expect(
        MovieBoxParser.isDeprecationNoticeUrl(url),
        MovieBoxParser.isTrailerOrNoticeUrl(url),
      );
    });
  });

  group('resourcePositionJsonToRelease', () {
    test('recovers the file and the metadata', () {
      const original = Release(
        provider: ProviderKind.moviebox,
        filename: 'Example Movie',
        quality: '1080p',
        codec: 'hevc',
        sizeBytes: 1010288591,
        resourceId: '6154402015721538488',
        season: 0,
        episode: 0,
      );
      final payload = {
        'data': {
          'list': [
            {
              'resourceId': '6154402015721538488',
              'resourceLink':
                  'https://cdn.example.com/resource/movie.mp4?sign=abc&t=123',
              'se': 0,
              'ep': 0,
              'resolution': 1080,
              'codecName': 'h264',
              'size': '1010288591',
              'uploadBy': 'uploader',
            },
          ],
        },
      };

      final recovered = MovieBoxParser.resourcePositionJsonToRelease(
        payload,
        original,
        userAgent: 'TestAgent',
      );
      expect(recovered, isNotNull);
      expect(recovered!.filename, original.filename);
      expect(recovered.quality, '1080p');
      expect(recovered.sizeBytes, 1010288591);
      expect(recovered.resourceId, original.resourceId);
      expect(
        recovered.directUrl,
        'https://cdn.example.com/resource/movie.mp4?sign=abc&t=123',
      );
      expect(recovered.mirrors.first.directFile, isTrue);
      expect(recovered.mirrors.first.headers.length, 1);
      expect(recovered.mirrors.first.headers.first.key, 'User-Agent');
    });

    test('rejects notices, wrong resources and wrong episodes', () {
      const original = Release(
        provider: ProviderKind.moviebox,
        filename: 'Episode 2',
        resourceId: 'episode2',
        season: 1,
        episode: 2,
      );
      final invalid = [
        {
          'resourceId': 'episode1',
          'se': 1,
          'ep': 2,
          'resourceLink': 'https://cdn.example.com/another.mp4',
        },
        {
          'resourceId': 'episode2',
          'se': 1,
          'ep': 1,
          'resourceLink': 'https://cdn.example.com/wrong-episode.mp4',
        },
        {
          'resourceId': 'episode2',
          'se': 2,
          'ep': 2,
          'resourceLink': 'https://cdn.example.com/wrong-season.mp4',
        },
        {
          'resourceId': 'episode2',
          'se': 1,
          'ep': 2,
          'resourceLink':
              'https://macdn.aoneroom.com/other/2026/10/10/upgrade.mp4',
        },
        {
          'resourceId': 'episode2',
          'se': 1,
          'ep': 2,
          'resourceLink': 'file:///tmp/movie.mp4',
        },
        {'resourceId': 'episode2', 'se': 1, 'ep': 2, 'resourceLink': ''},
      ];

      for (final item in invalid) {
        expect(
          MovieBoxParser.resourcePositionJsonToRelease(
            {
              'list': [item],
            },
            original,
            userAgent: 'TestAgent',
          ),
          isNull,
          reason: '$item must not be accepted',
        );
      }

      for (final payload in <Map<String, Object?>>[
        <String, Object?>{},
        {'list': <Object?>[]},
        {'data': null},
      ]) {
        expect(
          MovieBoxParser.resourcePositionJsonToRelease(
            payload,
            original,
            userAgent: 'TestAgent',
          ),
          isNull,
        );
      }
    });
  });

  group('MovieBoxClient paths', () {
    test('the episode listing targets the exact episode', () {
      for (final pair in const [(0, 0), (5, 1), (2, 25)]) {
        final path = MovieBoxClient.episodeResourcePath(
          '123',
          pair.$1,
          pair.$2,
        );
        final uri = Uri.parse('https://example.com$path');
        expect(uri.path, '/wefeed-mobile-bff/subject-api/resource/v2');
        expect(uri.queryParameters['subjectId'], '123');
        expect(uri.queryParameters['se'], '${pair.$1}');
        expect(uri.queryParameters['epFrom'], '${pair.$2}');
        expect(uri.queryParameters['epTo'], '${pair.$2}');
        expect(uri.queryParameters['page'], '1');
        expect(uri.queryParameters['isVip'], 'true');
      }
    });

    test('the failover path encodes the failed url', () {
      const origin = 'https://cdn.example.com/notice.mp4?sign=a+b&t=123';
      final path = MovieBoxClient.resourcePositionPath('123', '456', origin);
      final uri = Uri.parse('https://example.com$path');
      expect(uri.path, '/wefeed-mobile-bff/subject-api/resource-position/v2');
      expect(uri.queryParameters['subjectId'], '123');
      expect(uri.queryParameters['resourceId'], '456');
      expect(uri.queryParameters['failUrl'], origin);
      expect(uri.queryParameters['failCode'], '404');
      expect(uri.queryParameters['resourceNum'], '0');
      expect(uri.queryParameters['isVip'], 'true');
      expect(uri.queryParameters.length, 6);
    });
  });
}
