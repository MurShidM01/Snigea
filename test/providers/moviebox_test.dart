import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/providers/moviebox/moviebox_crypto.dart';
import 'package:snigea/providers/moviebox/moviebox_parser.dart';
import 'package:snigea/providers/moviebox/moviebox_session.dart';

void main() {
  group('MovieBoxCrypto', () {
    test('sorts the query string alphabetically', () {
      expect(
        MovieBoxCrypto.sortedQueryString(
          'https://api.example.com/endpoint?b=2&a=1&c=3',
        ),
        'a=1&b=2&c=3',
      );
      expect(
        MovieBoxCrypto.sortedQueryString('https://api.example.com/endpoint'),
        '',
      );
    });

    test('builds the client token', () {
      final token = MovieBoxCrypto.generateXClientToken(1700000000000);
      final parts = token.split(',');
      expect(parts.length, 2);
      expect(parts.first, '1700000000000');
      expect(parts.last.length, 32);
    });

    test('builds a signature with the documented shape', () {
      final signature = MovieBoxCrypto.generateXTrSignature(
        method: 'GET',
        url: 'https://api.example.com/path?tab=1&page=2',
        accept: 'application/json',
        contentType: 'application/json',
        timestampMs: 1700000000000,
      );
      final parts = signature.split('|');
      expect(parts.length, 3);
      expect(parts[0], '1700000000000');
      expect(parts[1], '2');
      expect(parts[2], isNotEmpty);
    });

    test('signs the canonical string', () {
      final canonical = MovieBoxCrypto.buildCanonicalString(
        method: 'get',
        url: 'https://api.example.com/path?b=2&a=1',
        accept: 'application/json',
        contentType: 'application/json',
        timestampMs: 1700000000000,
      );
      final lines = canonical.split('\n');
      expect(lines[0], 'GET');
      expect(lines[1], 'application/json');
      expect(lines[2], 'application/json');
      expect(lines[3], '');
      expect(lines[4], '1700000000000');
      expect(lines[5], '');
      expect(lines[6], '/path?a=1&b=2');
    });

    test('builds the signed headers', () {
      final headers = MovieBoxCrypto.buildSignedHeaders(
        method: 'POST',
        url: 'https://api.example.com/path',
        body: '{}',
        authToken: 'token',
        userAgent: 'Agent/1.0',
        clientInfo: '{}',
        spoofedIp: '1.2.3.4',
        timestampMs: 1700000000000,
      );
      expect(headers['Authorization'], 'Bearer token');
      expect(headers['x-client-status'], '0');
      expect(headers['x-forwarded-for'], '1.2.3.4');
      expect(headers['x-client-token'], isNotEmpty);
      expect(headers['x-tr-signature'], contains('|2|'));
    });

    test('generates a plausible device identity', () {
      final identity = MovieBoxCrypto.generateClientInfoAndUa();
      expect(identity.userAgent, contains('com.community.oneroom/500201'));
      expect(identity.userAgent, contains('Cronet/135.0.7012.3'));
      final json = jsonDecode(identity.clientInfo) as Map<String, dynamic>;
      expect(json['version_name'], '4.0.01.0813.03');
      expect(json['package_name'], 'com.community.oneroom');
      expect(json['sp_code'], '40401');
      expect(json['X-Play-Mode'], '2');
      expect(json['version_code'], isA<int>());
    });
  });

  group('MovieBoxSession', () {
    test('parses the jwt claims', () {
      const payload =
          '{"userId":"123456789","exp":1893456000,"role":"visitor"}';
      final encoded = base64Url
          .encode(utf8.encode(payload))
          .replaceAll('=', '');
      final token = 'eyJhbGciOiJIUzI1NiJ9.$encoded.signature';
      final claims = parseJwtClaims(token);
      expect(claims.userId, '123456789');
      expect(claims.expiresAt, 1893456000);
    });

    test('validates the session lifetime', () {
      final valid = MovieBoxSession(
        token: 'valid',
        createdAt: 0,
        expiresAt: 9999999999,
      );
      expect(valid.isValid(), isTrue);

      final expired = MovieBoxSession(
        token: 'expired',
        createdAt: 0,
        expiresAt: 100,
      );
      expect(expired.isValid(), isFalse);

      final empty = MovieBoxSession(
        token: '',
        createdAt: 0,
        expiresAt: 9999999999,
      );
      expect(empty.isValid(), isFalse);
    });
  });

  group('MovieBoxParser', () {
    test('parses a search payload', () {
      final payload = {
        'data': {
          'results': [
            {
              'subjects': [
                {
                  'subjectId': '12345',
                  'title': 'Inception',
                  'subjectType': 1,
                  'releaseDate': '2010-07-16',
                  'cover': {'url': 'https://example.com/cover.jpg'},
                  'season': 0,
                },
                {
                  'subjectId': '67890',
                  'title': 'Breaking Bad',
                  'subjectType': 2,
                  'releaseDate': '2008',
                  'cover': {'url': 'https://example.com/bb.jpg'},
                  'season': 5,
                },
              ],
            },
          ],
        },
      };

      final catalog = MovieBoxParser.searchJsonToCatalog(payload);
      expect(catalog.length, 2);
      expect(catalog.first.id.value, '12345');
      expect(catalog.first.title, 'Inception');
      expect(catalog.first.year, '2010');
      expect(catalog.last.id.value, '67890');
      expect(catalog.last.mediaType.name, 'series');
      expect(catalog.last.seasonCount, 5);
    });

    test('parses a details payload', () {
      final payload = {
        'data': {
          'subject': {
            'subjectId': '999',
            'title': 'Interstellar',
            'subjectType': 1,
            'releaseDate': '2014',
            'description': 'Space exploration film',
            'imdbRatingValue': 8.7,
            'director': 'Christopher Nolan',
            'stars': 'Matthew McConaughey, Anne Hathaway',
            'duration': 10140,
            'genre': ['Sci-Fi', 'Adventure'],
            'cover': {'url': 'https://example.com/interstellar.jpg'},
          },
        },
      };

      final details = MovieBoxParser.detailsJsonToMediaDetails(payload);
      expect(details.id.value, '999');
      expect(details.title, 'Interstellar');
      expect(details.director, 'Christopher Nolan');
      expect(details.imdbRating, '8.7');
      expect(details.duration, '169m');
      expect(details.genres, ['Sci-Fi', 'Adventure']);
    });

    test('parses the dubs and the seasons', () {
      final payload = {
        'data': {
          'subject': {
            'subjectId': '500',
            'title': 'Money Heist',
            'subjectType': 2,
            'dubs': [
              {
                'subjectId': '500',
                'lanName': 'Original',
                'title': 'Spanish (Original)',
              },
              {
                'subjectId': '501',
                'lanName': 'English',
                'title': 'English Dub',
              },
            ],
            'seasons': {
              'seasons': [
                {'se': 1, 'maxEp': 13},
              ],
            },
          },
        },
      };

      final details = MovieBoxParser.detailsJsonToMediaDetails(payload);
      expect(details.isSeries, isTrue);
      expect(details.hasLanguages, isTrue);
      expect(details.dubs.length, 2);
      expect(details.seasons.first.episodes.length, 13);
      expect(details.siblingIds(), ['500', '501']);
    });

    test('resolves the dash manifest from a cloudfront policy', () {
      const policyJson =
          '{"Statement":[{"Resource":"https://sacdn.example.com/dash/4179386086617137184_0_0_1080_h265_518/*"}]}';
      final encoded = base64.encode(utf8.encode(policyJson));
      final cookie =
          'CloudFront-Policy=$encoded;CloudFront-Signature=abc;CloudFront-Key-Pair-Id=KMHN1LQ1HEUPL;';

      expect(
        MovieBoxParser.resolveDashManifestFromPolicy(cookie),
        'https://sacdn.example.com/dash/4179386086617137184_0_0_1080_h265_518/index.mpd',
      );
    });

    test('resolves the dash manifest from an edge cache cookie', () {
      const cookie =
          'Edge-Cache-Cookie=urlprefix=aHR0cHM6Ly9zYmNkbjMuaGFrdW5heW1hdGF0YS5jb20vZGFzaC8zMjY0NzcyNTg4MzMzMTU3NDI0XzBfMF8xMDgwX2gyNjVfNTYwLw:sign=abc:t=123';
      expect(
        MovieBoxParser.resolveDashManifestFromPolicy(cookie),
        'https://sbcdn3.hakunaymatata.com/dash/3264772588333157424_0_0_1080_h265_560/index.mpd',
      );
    });

    test('rejects an hls policy and malformed policies', () {
      const hlsCookie =
          'Edge-Cache-Cookie=urlprefix=aHR0cHM6Ly9zYmNkbjMuaGFrdW5heW1hdGF0YS5jb20vaGxzLzUyODM0MjAzNzkzODAzMzU1NzYtMS0xLTcyMC05NDYv:sign=9d668fe770e7d41d067f80422544d47e:t=1791308037';
      expect(MovieBoxParser.resolveDashManifestFromPolicy(hlsCookie), isNull);
      expect(
        MovieBoxParser.resolveDashManifestFromPolicy('SomeOtherCookie=123'),
        isNull,
      );
      expect(
        MovieBoxParser.resolveDashManifestFromPolicy(
          'CloudFront-Policy=invalid_base64;',
        ),
        isNull,
      );
    });

    test('builds one release per resolution', () {
      const policyJson =
          '{"Statement":[{"Resource":"https://sacdn.example.com/dash/12345_0_0_1080_h265_518/*"}]}';
      final encoded = base64.encode(utf8.encode(policyJson));
      final cookie =
          'CloudFront-Policy=$encoded;CloudFront-Signature=xyz;CloudFront-Key-Pair-Id=K123;';

      final payload = {
        'code': 0,
        'data': {
          'title': 'Sample Movie',
          'displayResolutions': '480,720,1080',
          'streams': [
            {
              'id': '9999',
              'format': 'MP4',
              'codecName': 'hevc',
              'duration': 7200,
              'size': '1500000000',
              'resolutions': '1080,720,480',
              'url': 'https://macdn.example.com/notice.mp4',
              'signCookie': cookie,
            },
          ],
        },
      };

      final releases = MovieBoxParser.playInfoJsonToReleases(
        payload,
        season: 0,
        episode: 0,
        userAgent: 'TestAgent/1.0',
      );
      expect(releases.length, 3);
      expect(releases[0].quality, '1080p');
      expect(releases[1].quality, '720p');
      expect(releases[2].quality, '480p');
      expect(
        releases[0].directUrl,
        'https://sacdn.example.com/dash/12345_0_0_1080_h265_518/index.mpd',
      );
      final mirror = releases[0].mirrors.first;
      expect(
        mirror.headers.any(
          (header) =>
              header.key == 'Referer' &&
              header.value == 'https://sportslive.wine',
        ),
        isTrue,
      );
      expect(
        mirror.headers.any(
          (header) =>
              header.key == 'Cookie' &&
              header.value.contains('CloudFront-Policy='),
        ),
        isTrue,
      );
    });

    test('rejects a deprecation notice stream', () {
      final payload = {
        'code': 0,
        'data': {
          'title': 'Deprecation Notice Title',
          'streams': [
            {
              'id': '1',
              'format': 'MP4',
              'codecName': 'h264',
              'resolutions': '480',
              'url': 'https://macdn.aoneroom.com/other/2026/09/01/9a0461bc39da389663bf3dbb17091d3f.mp4',
              'signCookie': '',
            },
          ],
        },
      };

      final releases = MovieBoxParser.playInfoJsonToReleases(
        payload,
        season: 0,
        episode: 0,
        userAgent: 'TestAgent/1.0',
      );
      expect(releases, isEmpty);
    });

    test('keeps a legitimate direct stream', () {
      final payload = {
        'code': 0,
        'data': {
          'title': 'Legitimate Movie',
          'streams': [
            {
              'id': '1',
              'format': 'MP4',
              'codecName': 'h264',
              'resolutions': '1080',
              'url': 'https://cdn.example.com/legitimate_movie.mp4',
              'signCookie': '',
            },
          ],
        },
      };

      final releases = MovieBoxParser.playInfoJsonToReleases(
        payload,
        season: 0,
        episode: 0,
        userAgent: 'TestAgent/1.0',
      );
      expect(releases.length, 1);
      expect(
        releases.first.directUrl,
        'https://cdn.example.com/legitimate_movie.mp4',
      );
    });

    test('parses the caption payload', () {
      final payload = {
        'code': 0,
        'data': {
          'extCaptions': [
            {
              'id': '1',
              'lan': 'en',
              'lanName': 'English',
              'size': '1000',
              'url': 'https://example.com/en.srt',
            },
            {
              'id': '2',
              'lan': 'es',
              'lanName': '',
              'size': '1200',
              'url': 'https://example.com/es.srt',
            },
            {'id': '3', 'lan': '', 'lanName': '', 'url': ''},
            {
              'id': '4',
              'lan': 'en',
              'lanName': 'IN',
              'size': '34',
              'url': 'https://pacdn.aoneroom.com/other/2024/09/18/aa348f2541d13ffe1a8ea6f9e14f3ed5.srt',
            },
          ],
        },
      };

      final options = MovieBoxParser.captionsJsonToOptions(payload);
      expect(options.length, 2);
      expect(options[0].name, 'English');
      expect(options[1].name, 'es');
    });

    test('parses the resource list', () {
      final payload = {
        'list': [
          {
            'fileName': 'Money.Heist.S01E01.1080p.NF.WEB-DL.x265',
            'resolution': 1080,
            'codecName': 'hevc',
            'size': '850000000',
            'se': 1,
            'ep': 1,
            'resourceLink': 'https://stream.example.com/mh0101.mp4',
            'uploadBy': 'NF',
          },
          {
            'resourceId': 4087841675127701904,
            'title': 'Steins;Gate S01E07',
            'url': 'https://macdn.aoneroom.com/other/2026/09/04/b164fbfb4347792950bdfbfb563d39d9.mp4',
          },
        ],
      };

      final releases = MovieBoxParser.resourceJsonToReleases(payload);
      expect(releases.length, 1);
      expect(
        releases.first.filename,
        'Money.Heist.S01E01.1080p.NF.WEB-DL.x265',
      );
      expect(releases.first.resolutionU64, 1080);
      expect(releases.first.season, 1);
      expect(releases.first.episode, 1);
      expect(releases.first.directUrl, 'https://stream.example.com/mh0101.mp4');
      expect(releases.first.sourceLabel, 'NF');
    });

    test('parses the homepage payload', () {
      final payload = {
        'items': [
          {
            'subjects': [
              {'subjectId': '1', 'title': 'First'},
              {'subjectId': '2', 'title': 'Second'},
            ],
          },
        ],
      };

      final (items, metrics) = MovieBoxParser.homepageJsonToCatalog(payload);
      expect(items.length, 2);
      expect(metrics['1']!.trending, 1000);
      expect(metrics['2']!.trending, 999);
    });
  });
}
