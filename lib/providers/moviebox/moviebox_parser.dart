import 'dart:convert';

import '../../core/crypto/digest.dart';
import '../../core/json/json_utils.dart';
import '../../core/text/cleaners.dart';
import '../../core/text/moviebox_title.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';

/// The referer required by the MovieBox CDN.
const String movieBoxStreamReferer = 'https://sportslive.wine';

/// Parsing helpers for the MovieBox BFF payloads.
///
/// The rules are a direct port of the reference implementation so that the
/// same provider responses produce the same catalogue, metadata and streams.
abstract final class MovieBoxParser {
  /// Converts the `get-ext-captions` payload into selectable subtitle tracks.
  static List<SubtitleOption> captionsJsonToOptions(Object? payload) {
    final map = asMap(payload);
    final captions = asList(
      pick(map, ['extCaptions']) ??
          asList(asMap(pick(map, ['data']))?['extCaptions']),
    );
    if (captions == null) return const [];

    final seenUrls = <String>{};
    final options = <SubtitleOption>[];
    for (final entry in captions) {
      final cap = asMap(entry);
      if (cap == null) continue;
      final url = asString(cap['url']);
      if (url == null || url.isEmpty || url.contains('aa348f2541d13ffe')) {
        continue;
      }
      final size = asInt(cap['size']) ?? 0;
      if (size > 0 && size <= 50) continue;
      final rawName = asString(cap['lanName'])?.trim();
      final name = (rawName != null && rawName.isNotEmpty)
          ? rawName
          : (asString(cap['lan']) ?? 'Unknown');
      if (name.toLowerCase() == 'in' && (size == 0 || size <= 100)) continue;
      if (!seenUrls.add(url)) continue;
      options.add(SubtitleOption(name: name, url: url));
    }
    return options;
  }

  /// Converts a single subject object into a catalogue entry.
  static CatalogItem? subjectJsonToCatalogItem(Object? raw) {
    final subject = asMap(raw);
    if (subject == null) return null;

    final idValue = pick(subject, ['subjectId', 'id']);
    final id = asString(idValue);
    if (id == null || id.isEmpty) return null;

    final title = asString(pick(subject, ['title', 'name'])) ?? 'Unknown';

    final stype = asInt(pick(subject, ['subjectType', 'stype'])) ?? 1;
    final mediaType = stype == 2 ? MediaType.series : MediaType.movie;

    final yearRaw = asString(
      pick(subject, ['releaseDate', 'year', 'releaseInfo']),
    );
    final year = yearRaw == null ? null : extract4DigitYear(yearRaw);

    final posterUrl = asString(
      pick(subject, ['coverUrl', 'poster', 'pic']) ??
          asString(asMap(subject['cover'])?['url']),
    );

    final seasonCount = asInt(subject['season']);

    return CatalogItem(
      id: ProviderMediaId(provider: ProviderKind.moviebox, value: id),
      title: title,
      mediaType: mediaType,
      year: (year == null || year.isEmpty) ? null : year,
      posterUrl: posterUrl,
      seasonCount: seasonCount,
    );
  }

  /// Converts the search payload into catalogue entries.
  static List<CatalogItem> searchJsonToCatalog(Object? payload) {
    final map = asMap(payload);
    List<Object?>? subjects;

    final data = asMap(map?['data']);
    final results = asList(data?['results'] ?? map?['results']);
    if (results != null && results.isNotEmpty) {
      final first = asMap(results.first);
      subjects = asList(first?['subjects']);
    }
    subjects ??= asList(data?['list'] ?? map?['list']);

    if (subjects == null) return const [];
    final items = <CatalogItem>[];
    for (final subject in subjects) {
      final item = subjectJsonToCatalogItem(subject);
      if (item != null) items.add(item);
    }
    return items;
  }

  /// Converts the homepage payload into catalogue entries plus rank metrics.
  static (List<CatalogItem> items, Map<String, BrowseMetrics> metrics)
  homepageJsonToCatalog(Object? payload) {
    final items = <CatalogItem>[];
    final metrics = <String, BrowseMetrics>{};
    final seenIds = <String>{};

    final groups = asList(asMap(payload)?['items']) ?? asList(payload);
    if (groups == null) return (items, metrics);

    for (final group in groups) {
      final groupMap = asMap(group);
      if (groupMap == null) continue;

      final subjects = <Object?>[];

      final banner = asMap(groupMap['banner']);
      for (final bannerItem in asList(banner?['banners']) ?? const []) {
        final subject = asMap(bannerItem)?['subject'];
        if (subject != null) subjects.add(subject);
      }
      final customData = asMap(groupMap['customData']);
      for (final customItem in asList(customData?['items']) ?? const []) {
        final subject = asMap(customItem)?['subject'];
        if (subject != null) subjects.add(subject);
      }
      for (final subject in asList(groupMap['subjects']) ?? const []) {
        subjects.add(subject);
      }

      for (var index = 0; index < subjects.length; index++) {
        final item = subjectJsonToCatalogItem(subjects[index]);
        if (item == null) continue;
        if (!seenIds.add(item.id.value)) continue;
        var metric = extractBrowseMetrics(subjects[index]);
        metric = BrowseMetrics(
          trending:
              metric.trending ??
              (1000 - (index > 999 ? 999 : index)).toDouble(),
          rating: metric.rating,
          recentRating: metric.recentRating,
          popularity: metric.popularity,
        );
        metrics[item.id.value] = metric;
        items.add(item);
      }
    }

    return (items, metrics);
  }

  /// Extracts the ranking metrics advertised by a subject object.
  static BrowseMetrics extractBrowseMetrics(Object? raw) {
    final item = asMap(raw);
    if (item == null) return const BrowseMetrics();
    return BrowseMetrics(
      trending: _metricValue(item, const [
        '__browse_rank',
        'imdb_trending',
        'imdbTrending',
        'trending',
      ]),
      rating: _metricValue(item, const [
        'imdbRatingValue',
        'imdbRate',
        'imdb_rating',
        'imdbRating',
      ]),
      recentRating: _metricValue(item, const [
        'imdb_rating_30d',
        'imdbRating30Days',
        'imdbRatingLast30Days',
        'imdb_rating_recent',
        'imdbRatingValue',
        'imdbRate',
      ]),
      popularity: _metricValue(item, const [
        '__browse_rank',
        'imdb_popularity',
        'imdbPopularity',
        'popularity',
        'viewers',
      ]),
    );
  }

  static double? _metricValue(Map<String, Object?> item, List<String> keys) {
    final containers = <Map<String, Object?>?>[
      item,
      asMap(item['metadata']),
      asMap(item['meta']),
    ];
    for (final container in containers) {
      if (container == null) continue;
      for (final key in keys) {
        final value = asDouble(container[key]);
        if (value != null) return value;
      }
    }
    return null;
  }

  /// Converts the `get` payload into full metadata.
  static MediaDetails detailsJsonToMediaDetails(Object? payload) {
    final map = asMap(payload);
    final subject =
        asMap(asMap(map?['data'])?['subject']) ?? asMap(map?['subject']) ?? map;

    if (subject == null) {
      throw const FormatException(
        'MovieBox response did not contain a subject',
      );
    }

    final idValue = pick(subject, ['subjectId', 'id']);
    final id = asString(idValue);
    if (id == null || id.isEmpty) {
      throw const FormatException('MovieBox subject did not contain an id');
    }

    final title = asString(subject['title']) ?? 'Unknown';
    final stype = asInt(pick(subject, ['subjectType', 'stype'])) ?? 1;
    final mediaType = stype == 2 ? MediaType.series : MediaType.movie;

    final yearRaw = asString(pick(subject, ['releaseDate', 'year']));
    final year = yearRaw == null ? null : extract4DigitYear(yearRaw);

    final description = asString(pick(subject, ['description', 'intro']));
    final tagline = asString(subject['tagline']);

    final ratingRaw = pick(subject, ['imdbRatingValue', 'rating']);
    final imdbRating = ratingRaw is num
        ? ratingRaw.toStringAsFixed(1)
        : asString(ratingRaw);

    final director = asString(subject['director']);
    final stars = asString(subject['stars']);
    final prints = asString(subject['prints']);
    final audios = asString(subject['audios']);

    final posterUrl = asString(
      asString(asMap(subject['cover'])?['url']) ??
          asString(subject['coverUrl']),
    );

    String? duration;
    final durationRaw = subject['duration'];
    final durationNumber = asInt(durationRaw);
    if (durationNumber != null) {
      if (durationNumber > 0) {
        duration = '${durationNumber ~/ 60}m';
      }
    } else {
      final durationText = asString(durationRaw)?.trim();
      if (durationText != null &&
          durationText.isNotEmpty &&
          durationText != '0m' &&
          durationText != '0') {
        duration = durationText;
      }
    }

    final genres = (asList(pick(subject, ['genre', 'genres'])) ?? const [])
        .map(asString)
        .whereType<String>()
        .toList();

    final seasons = <Season>[];
    final seasonsRaw = subject['seasons'];
    final seasonsList = asList(
      asMap(seasonsRaw)?['seasons'] ?? (seasonsRaw is List ? seasonsRaw : null),
    );
    if (seasonsList != null) {
      for (final entry in seasonsList) {
        final seasonMap = asMap(entry);
        if (seasonMap == null) continue;
        final seasonNumber = asInt(seasonMap['se']) ?? 1;
        final episodes = <Episode>[];
        final episodeNumbers = asList(seasonMap['episodeNumbers']);
        if (episodeNumbers != null) {
          for (final episode in episodeNumbers) {
            final number = asInt(episode);
            if (number != null) {
              episodes.add(Episode(season: seasonNumber, number: number));
            }
          }
        } else {
          final maxEpisode = asInt(seasonMap['maxEp']);
          if (maxEpisode != null) {
            for (var number = 1; number <= maxEpisode; number++) {
              episodes.add(Episode(season: seasonNumber, number: number));
            }
          }
        }
        seasons.add(Season(number: seasonNumber, episodes: episodes));
      }
    }

    final dubs = <AudioTrackOption>[];
    for (final entry in asList(subject['dubs']) ?? const []) {
      final dub = asMap(entry);
      if (dub == null) continue;
      final subjectId = asString(pick(dub, ['subjectId', 'id'])) ?? '';
      final language =
          asString(pick(dub, ['lanName', 'language', 'lang'])) ?? 'Unknown';
      final label =
          asString(pick(dub, ['title', 'name', 'lanName'])) ?? language;
      dubs.add(
        AudioTrackOption(
          subjectId: subjectId,
          language: language,
          label: label,
        ),
      );
    }

    return MediaDetails(
      id: ProviderMediaId(provider: ProviderKind.moviebox, value: id),
      title: title,
      mediaType: mediaType,
      year: (year == null || year.isEmpty) ? null : year,
      description: description,
      tagline: tagline,
      imdbRating: imdbRating,
      director: director,
      stars: stars,
      prints: prints,
      audios: audios,
      posterUrl: posterUrl,
      duration: duration,
      genres: genres,
      seasons: seasons,
      dubs: dubs,
    );
  }

  /// Converts a single `resource` list item into a release.
  static Release resourceItemToRelease(Object? raw) {
    final item = asMap(raw) ?? const {};
    final filename =
        asString(pick(item, ['fileName', 'title'])) ?? 'Unknown Release';

    final resolutionRaw = item['resolution'];
    final resolution = asInt(resolutionRaw) != null
        ? '${asInt(resolutionRaw)}p'
        : asString(resolutionRaw);

    final codec = asString(pick(item, ['codecName', 'codec']));
    final language = asString(pick(item, ['language', 'lanName']));
    final sizeBytes = asInt(item['size']);
    final season = asInt(item['se']);
    final episode = asInt(item['ep']);
    final resourceId = asString(pick(item, ['resourceId', 'id']));

    final mirrors = <SourceMirror>[];
    final link = asString(pick(item, ['resourceLink', 'url']));
    if (link != null && link.isNotEmpty && !isDeprecationNoticeUrl(link)) {
      final label = asString(pick(item, ['uploadBy', 'source'])) ?? 'Direct';
      mirrors.add(
        SourceMirror(
          label: label,
          resolverUrl: link,
          headers: const [],
          directFile: false,
        ),
      );
    }

    return Release(
      provider: ProviderKind.moviebox,
      filename: filename,
      quality: resolution,
      codec: codec,
      language: language,
      sizeBytes: sizeBytes,
      season: season,
      episode: episode,
      mirrors: mirrors,
      resourceId: resourceId,
    );
  }

  /// True for the placeholder videos MovieBox serves for unavailable titles.
  ///
  /// The reference implementation also rejected every `macdn.aoneroom.com`
  /// link below `/other/`. Live responses now serve real streams from that
  /// very path, so the rule is limited to the known notice files and the
  /// `/notice.mp4` marker. The three hashes below are the notice videos that
  /// the upstream API still returns for locked or unavailable titles.
  /// True for the placeholder clip that upstream returns instead of a
  /// stream.
  ///
  /// Since October 2026 the `play-info` endpoint answers with the *site
  /// trailer* (a roughly 23 second MP4 of about 824 KB) instead of the real
  /// media, and the `resource` endpoint points `resourceLink` at the very
  /// same file. Those URLs are byte identical for every title and must never
  /// be offered as a playable mirror.
  ///
  /// The trailer lives on `macdn.aoneroom.com` below `/other/<date>/<hash>.mp4`.
  /// Real media is served from the `*.hakunaymatata.com` CDN with a
  /// `?sign=<token>&t=<expiry>` query.
  static bool isTrailerOrNoticeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('1c7de0bd3393702d9191801f15f88f8d') ||
        lower.contains('9a0461bc39da389663bf3dbb17091d3f') ||
        lower.contains('b164fbfb4347792950bdfbfb563d39d9') ||
        lower.contains('/notice.mp4') ||
        (lower.contains('macdn.aoneroom.com') && lower.contains('/other/'));
  }

  /// Legacy alias of [isTrailerOrNoticeUrl].
  static bool isDeprecationNoticeUrl(String url) => isTrailerOrNoticeUrl(url);

  /// Parses the `resourceDetectors` block of a subject-details payload into
  /// releases.
  ///
  /// The details endpoint keeps exposing the real media even while
  /// `play-info` only returns the trailer. Every detector holds a
  /// `resolutionList` whose entries carry a signed CDN link
  /// (`?sign=<token>&t=<expiry>`), the real file size, duration and codec,
  /// so a release built from it is playable where a `play-info` release is
  /// not.
  ///
  /// The CDN expects the MovieBox app user agent and rejects a `Referer`
  /// header with HTTP 429, therefore every mirror carries the user agent
  /// only.
  static List<Release> detectorJsonToReleases(
    Object? payload, {
    required int season,
    required int episode,
    required String userAgent,
  }) {
    final map = asMap(payload);
    final data = asMap(map?['data']) ?? map;
    final detectors = asList(data?['resourceDetectors']);
    if (detectors == null) return const [];

    final releases = <Release>[];

    for (final detectorEntry in detectors) {
      final detector = asMap(detectorEntry);
      if (detector == null) continue;

      final detectorCodec = _nonEmpty(asString(detector['codecName']));
      final detectorSource = asString(detector['source']) ?? 'MovieBox';
      final detectorUploader = asString(detector['uploadBy']) ?? 'Direct';

      final entries = asList(detector['resolutionList']);
      if (entries == null) continue;

      for (final entryValue in entries) {
        final entry = asMap(entryValue);
        if (entry == null) continue;

        final entrySeason = asInt(entry['se']);
        final entryEpisode = asInt(entry['ep']);

        // A request for a specific episode must not pick up the links of
        // another one. Movie subjects report `se = 0` / `ep = 0`.
        if (season != 0 || episode != 0) {
          final matches =
              (entrySeason == null || entrySeason == season) &&
              (entryEpisode == null || entryEpisode == episode);
          if (!matches) continue;
        }

        final link = _nonEmpty(asString(entry['resourceLink'] ?? entry['url']));
        if (link == null) continue;
        if (isTrailerOrNoticeUrl(link)) continue;

        final resolution = _resolutionLabel(entry['resolution']);
        final codec = _nonEmpty(asString(entry['codecName'])) ?? detectorCodec;
        final sizeBytes = asInt(entry['size']);
        final title = _nonEmpty(asString(entry['title']));
        final filename =
            title ??
            (resolution != null
                ? '$detectorUploader $resolution'
                : detectorUploader);
        final language = asString(entry['language'] ?? entry['lanName']);
        final resourceId = asString(entry['resourceId'] ?? entry['id']);

        final label =
            _nonEmpty(asString(entry['uploadBy'])) ??
            (detectorUploader.trim().isEmpty
                ? detectorSource
                : detectorUploader);

        releases.add(
          Release(
            provider: ProviderKind.moviebox,
            filename: filename,
            quality: resolution,
            codec: codec,
            language: language,
            sizeBytes: sizeBytes,
            season: entrySeason,
            episode: entryEpisode,
            mirrors: [
              SourceMirror(
                label: label,
                resolverUrl: link,
                // The CDN answers 429 when a Referer is sent.
                headers: [MapEntry('User-Agent', userAgent)],
                directFile: true,
              ),
            ],
            resourceId: resourceId,
          ),
        );
      }
    }

    releases.sort((left, right) {
      final byResolution = right.resolutionU64.compareTo(left.resolutionU64);
      if (byResolution != 0) return byResolution;
      return (right.sizeBytes ?? 0).compareTo(left.sizeBytes ?? 0);
    });
    return releases;
  }

  /// Recovers the original file of a release through the resource failover
  /// API.
  ///
  /// The listing may point at the upgrade clip; the `resource-position/v2`
  /// endpoint then answers with the signed media file of the same resource.
  static Release? resourcePositionJsonToRelease(
    Object? payload,
    Release original, {
    required String userAgent,
  }) {
    final resourceId = original.resourceId;
    if (resourceId == null) return null;

    final map = asMap(payload);
    final data = asMap(map?['data']) ?? map;
    final items = asList(data?['list']);
    if (items == null) return null;

    for (final item in items) {
      final itemMap = asMap(item);
      if (itemMap == null) continue;

      final candidate = resourceItemToRelease(itemMap);
      if (candidate.resourceId != resourceId) continue;
      if (candidate.season != original.season) continue;
      if (candidate.episode != original.episode) continue;

      final url = _nonEmpty(
        asString(itemMap['resourceLink'] ?? itemMap['url']),
      );
      if (url == null) continue;
      final uri = Uri.tryParse(url);
      if (uri == null) continue;
      if (uri.scheme != 'http' && uri.scheme != 'https') continue;
      if (isTrailerOrNoticeUrl(url)) continue;

      final label =
          _nonEmpty(asString(itemMap['uploadBy'])) ??
          (candidate.mirrors.isNotEmpty
              ? candidate.mirrors.first.label
              : original.sourceLabel);

      return Release(
        provider: original.provider,
        filename: original.filename,
        // The recovered entry describes the real file, so its metadata is
        // more precise than the one of the placeholder listing.
        quality: candidate.quality ?? original.quality,
        codec: candidate.codec ?? original.codec,
        language: candidate.language ?? original.language,
        sizeBytes: candidate.sizeBytes ?? original.sizeBytes,
        season: original.season,
        episode: original.episode,
        mirrors: [
          SourceMirror(
            label: label,
            resolverUrl: url,
            // Direct MP4 files reject the DASH referer with HTTP 429.
            headers: [MapEntry('User-Agent', userAgent)],
            directFile: true,
          ),
        ],
        resourceId: original.resourceId,
      );
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _resolutionLabel(Object? raw) {
    final number = asInt(raw);
    if (number != null) return '${number}p';
    return _nonEmpty(asString(raw));
  }

  /// Extracts the DASH manifest URL from a signed CDN cookie.
  ///
  /// Both the `CloudFront-Policy` and the `Edge-Cache-Cookie` variants are
  /// supported; only `/dash/` resources are accepted.
  static String? resolveDashManifestFromPolicy(String signCookie) {
    for (final part in signCookie.split(';')) {
      final trimmed = part.trim();

      final prefixIndex = trimmed.indexOf('urlprefix=');
      if (prefixIndex >= 0) {
        final prefixPart = trimmed.substring(prefixIndex + 'urlprefix='.length);
        final b64Token = prefixPart.split(':').first.trim();
        final decoded = base64DecodeTolerant(b64Token);
        if (decoded != null) {
          try {
            final url = utf8.decode(decoded);
            final mpd = toDashMpd(url);
            if (mpd != null) return mpd;
          } on FormatException {
            // fall through to the next cookie part
          }
        }
      }

      if (trimmed.startsWith('CloudFront-Policy=')) {
        final policyClean = trimmed
            .substring('CloudFront-Policy='.length)
            .trim();
        final normalized = policyClean
            .replaceAll('-', '+')
            .replaceAll('_', '=')
            .replaceAll('~', '/');
        final decoded = base64DecodeTolerant(normalized);
        if (decoded == null) continue;
        try {
          final json = jsonDecode(utf8.decode(decoded));
          final statements = asList(asMap(json)?['Statement']);
          if (statements == null || statements.isEmpty) continue;
          final resource = asString(asMap(statements.first)?['Resource']);
          if (resource == null) continue;
          final mpd = toDashMpd(resource);
          if (mpd != null) return mpd;
        } on FormatException {
          continue;
        }
      }
    }
    return null;
  }

  /// Converts a `/dash/` root into its `index.mpd` manifest.
  static String? toDashMpd(String url) {
    var base = url.trim();
    while (base.endsWith('*')) {
      base = base.substring(0, base.length - 1);
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.isEmpty) return null;
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      return null;
    }
    if (!base.contains('/dash/')) return null;
    return '$base/index.mpd';
  }

  /// Converts the `play-info` payload into playable releases.
  static List<Release> playInfoJsonToReleases(
    Object? payload, {
    required int season,
    required int episode,
    required String userAgent,
  }) {
    final map = asMap(payload);
    final data = asMap(map?['data']) ?? map;
    if (data == null) return const [];

    final rawTitle = asString(data['title']) ?? 'MovieBox Stream';
    final titlePrefix = cleanMovieBoxTitle(rawTitle);

    final streams = asList(data['streams']);
    if (streams == null) return const [];

    final releases = <Release>[];
    for (final stream in streams) {
      final streamMap = asMap(stream);
      if (streamMap == null) continue;

      final streamId = asString(streamMap['id']);
      final formatType = asString(streamMap['format']) ?? 'MP4';
      final codec = asString(pick(streamMap, ['codecName', 'codec']));
      final sizeBytes = asInt(streamMap['size']);

      final resolutionsRaw =
          asString(
            pick(streamMap, ['resolutions']) ?? data['displayResolutions'],
          ) ??
          '1080,720,480';

      final signCookie = asString(streamMap['signCookie']) ?? '';
      final streamUrl = asString(streamMap['url']) ?? '';

      final manifestUrl =
          resolveDashManifestFromPolicy(signCookie) ??
          (isDeprecationNoticeUrl(streamUrl)
              ? null
              : (streamUrl.startsWith('http') ? streamUrl : null));
      if (manifestUrl == null) continue;

      final headers = <MapEntry<String, String>>[
        const MapEntry('Referer', movieBoxStreamReferer),
        MapEntry('User-Agent', userAgent),
      ];
      if (signCookie.isNotEmpty) {
        final cleanCookie = signCookie
            .replaceAll(RegExp(r';\s*$'), '')
            .split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .join('; ');
        headers.add(MapEntry('Cookie', cleanCookie));
      }

      final parsedResolutions =
          resolutionsRaw
              .split(',')
              .map((s) => int.tryParse(s.trim()))
              .whereType<int>()
              .toList()
            ..sort((a, b) => b.compareTo(a));
      final uniqueResolutions = <int>[];
      for (final value in parsedResolutions) {
        if (!uniqueResolutions.contains(value)) uniqueResolutions.add(value);
      }
      final resList = uniqueResolutions.isEmpty ? [1080] : uniqueResolutions;

      final codecDisplay = codec ?? formatType;
      final highestRes = resList.first.toDouble();

      for (final res in resList) {
        final resLabel = '${res}p';
        final filename = (season > 0 && episode > 0)
            ? '$titlePrefix S${season.toString().padLeft(2, '0')}'
                  'E${episode.toString().padLeft(2, '0')} $resLabel $codecDisplay'
            : '$titlePrefix $resLabel $codecDisplay';

        final mirror = SourceMirror(
          label: '$resLabel $codecDisplay',
          resolverUrl: manifestUrl,
          headers: headers,
          directFile: true,
        );

        int? scaledSize;
        if (sizeBytes != null) {
          if (res >= highestRes || highestRes <= 0) {
            scaledSize = sizeBytes;
          } else {
            final scale = _pow(res / highestRes, 1.6).clamp(0.15, 1.0);
            scaledSize = (sizeBytes * scale).round();
          }
        }

        releases.add(
          Release(
            provider: ProviderKind.moviebox,
            filename: filename,
            quality: resLabel,
            codec: codec,
            language: null,
            sizeBytes: scaledSize,
            season: season > 0 ? season : null,
            episode: episode > 0 ? episode : null,
            mirrors: [mirror],
            resourceId: streamId,
          ),
        );
      }
    }
    return releases;
  }

  /// The raw entries of a `resource` listing.
  static List<Map<String, Object?>> resourceItems(Object? payload) {
    final map = asMap(payload);
    final items = asList(map?['list']) ?? asList(payload) ?? const [];
    return items.map(asMap).whereType<Map<String, Object?>>().toList();
  }

  /// Converts the `resource` payload into releases.
  static List<Release> resourceJsonToReleases(Object? payload) {
    final map = asMap(payload);
    final items = asList(map?['list']) ?? asList(payload) ?? const [];
    final releases = <Release>[];
    for (final item in items) {
      final release = resourceItemToRelease(item);
      if (release.mirrors.isEmpty) continue;
      releases.add(release);
    }
    return releases;
  }

  static double _pow(double base, double exponent) {
    // Small helper so that the port does not depend on dart:math's pow for
    // fractional exponents (which is not available).
    if (base <= 0) return 0;
    return _exp(exponent * _log(base));
  }

  static double _log(double value) {
    // Natural logarithm via the series around 1, sufficient for our range.
    if (value <= 0) return double.negativeInfinity;
    var z = (value - 1) / (value + 1);
    var sum = 0.0;
    var term = z;
    for (var i = 1; i < 40; i += 2) {
      sum += term / i;
      term *= z * z;
    }
    return 2 * sum;
  }

  static double _exp(double value) {
    if (value.isNaN) return double.nan;
    var sum = 1.0;
    var term = 1.0;
    for (var i = 1; i < 30; i++) {
      term *= value / i;
      sum += term;
    }
    return sum;
  }
}
