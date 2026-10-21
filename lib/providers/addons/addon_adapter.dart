import '../../core/text/cleaners.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import 'addon_models.dart';

/// Converts addon payloads into the Snigea domain model.
///
/// The rules are a direct port of the reference adapter.
abstract final class AddonAdapter {
  /// True when the addon type describes a series.
  static bool isSeriesType(String? type) {
    final value = (type ?? '').toLowerCase();
    return value == 'series' || value == 'tv' || value == 'anime';
  }

  /// Converts a catalogue entry into a Snigea catalogue item.
  static CatalogItem metaToCatalogItem(MetaItem item) {
    final isSeries = isSeriesType(item.type);
    final yearRaw = item.releaseInfo ?? item.year ?? item.released;
    final year = yearRaw == null ? null : extract4DigitYear(yearRaw);

    final title = item.name.trim().isNotEmpty
        ? item.name
        : (item.title ?? 'Unknown');

    final posterUrl = item.poster ?? item.cover;
    final typePrefix = isSeries ? 'series' : 'movie';

    return CatalogItem(
      id: ProviderMediaId(
        provider: ProviderKind.addons,
        value: '$typePrefix:${item.id}',
      ),
      title: title,
      mediaType: isSeries ? MediaType.series : MediaType.movie,
      year: (year == null || year.isEmpty) ? null : year,
      posterUrl: posterUrl,
    );
  }

  /// Converts addon metadata into Snigea metadata.
  static MediaDetails metaDetailToMediaDetails(MetaDetail detail) {
    final isSeries = isSeriesType(detail.type) || detail.videos.isNotEmpty;

    final seasonMap = <int, Map<int, (String?, String?)>>{};
    for (final video in detail.videos) {
      final season = video.season ?? 1;
      final episode = video.episode ?? video.number ?? 1;
      final episodeMap = seasonMap.putIfAbsent(season, () => {});
      episodeMap.putIfAbsent(
        episode,
        () => (video.title ?? video.name, video.overview ?? video.description),
      );
    }

    final seasons = <Season>[];
    final seasonKeys = seasonMap.keys.toList()..sort();
    for (final season in seasonKeys) {
      final episodeMap = seasonMap[season]!;
      final episodeKeys = episodeMap.keys.toList()..sort();
      seasons.add(
        Season(
          number: season,
          episodes: episodeKeys
              .map(
                (number) => Episode(
                  season: season,
                  number: number,
                  title: episodeMap[number]!.$1,
                  overview: episodeMap[number]!.$2,
                ),
              )
              .toList(),
        ),
      );
    }

    final yearRaw = detail.releaseInfo ?? detail.year ?? detail.released ?? '';
    var year = extract4DigitYear(yearRaw);
    if (year.isEmpty) {
      year = yearRaw;
    }

    final title = detail.name.trim().isNotEmpty
        ? detail.name
        : (detail.title ?? 'Unknown');

    final posterUrl = detail.poster ?? detail.cover ?? detail.background;
    final description =
        detail.description ?? detail.overview ?? detail.synopsis;

    String? director;
    if (detail.director.isNotEmpty) {
      director = detail.director.join(', ');
    } else if (detail.directors.isNotEmpty) {
      director = detail.directors.join(', ');
    } else if (detail.writers.isNotEmpty) {
      director = detail.writers.join(', ');
    } else if (detail.writer.isNotEmpty) {
      director = detail.writer.join(', ');
    }

    String? stars;
    if (detail.cast.isNotEmpty) {
      stars = detail.cast.join(', ');
    } else if (detail.stars.isNotEmpty) {
      stars = detail.stars.join(', ');
    }

    final typePrefix = isSeries ? 'series' : 'movie';

    return MediaDetails(
      id: ProviderMediaId(
        provider: ProviderKind.addons,
        value: '$typePrefix:${detail.id}',
      ),
      title: title,
      mediaType: isSeries ? MediaType.series : MediaType.movie,
      year: year.isEmpty ? null : year,
      description: description,
      tagline: null,
      imdbRating: detail.imdbRating ?? detail.rating,
      director: director,
      stars: stars,
      prints: null,
      audios: null,
      posterUrl: posterUrl,
      duration: detail.runtime,
      genres: detail.genres.isNotEmpty ? detail.genres : detail.genre,
      seasons: seasons,
      dubs: const [],
    );
  }

  /// Detects the advertised quality of an addon stream.
  static String? parseQuality(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('2160P') ||
        upper.contains('4K') ||
        upper.contains('UHD')) {
      return '2160p';
    }
    if (upper.contains('1080P') ||
        upper.contains('FHD') ||
        upper.contains('FULL HD') ||
        upper.contains('FULLHD')) {
      return '1080p';
    }
    if (upper.contains('720P') ||
        upper.split(RegExp(r'[^A-Za-z0-9]')).contains('HD')) {
      return '720p';
    }
    if (upper.contains('480P') ||
        upper.split(RegExp(r'[^A-Za-z0-9]')).contains('SD')) {
      return '480p';
    }
    return null;
  }

  /// Detects the advertised codec of an addon stream.
  static String? parseCodec(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('HEVC') ||
        upper.contains('X265') ||
        upper.contains('H.265') ||
        upper.contains('H265')) {
      return 'HEVC/x265';
    }
    if (upper.contains('X264') ||
        upper.contains('H.264') ||
        upper.contains('H264') ||
        upper.contains('AVC')) {
      return 'AVC/x264';
    }
    if (upper.contains('AV1')) return 'AV1';
    return null;
  }

  /// Detects the advertised audio tracks of an addon stream.
  static String? parseAudioTracks(String text) {
    final upper = text.toUpperCase();
    const candidates = <String, String>{
      'HINDI': 'Hindi',
      'ENGLISH': 'English',
      'ENG': 'English',
      'HIN': 'Hindi',
      'TAMIL': 'Tamil',
      'TELUGU': 'Telugu',
      'BENGALI': 'Bengali',
      'BEN': 'Bengali',
      'MALAYALAM': 'Malayalam',
      'KANNADA': 'Kannada',
      'MARATHI': 'Marathi',
      'PUNJABI': 'Punjabi',
      'GUJARATI': 'Gujarati',
      'URDU': 'Urdu',
      'SPANISH': 'Spanish',
      'FRENCH': 'French',
      'GERMAN': 'German',
      'ITALIAN': 'Italian',
      'JAPANESE': 'Japanese',
      'JAP': 'Japanese',
      'KOREAN': 'Korean',
      'KOR': 'Korean',
      'RUSSIAN': 'Russian',
      'CHINESE': 'Chinese',
      'DUAL': 'Dual Audio',
      'MULTI': 'Multi Audio',
    };

    final languages = <String>[];
    candidates.forEach((needle, label) {
      if (upper.contains(needle) && !languages.contains(label)) {
        languages.add(label);
      }
    });
    if (languages.isEmpty) return null;
    return languages.join(' + ');
  }

  /// Derives a readable label from the host of a stream URL.
  static String? extractDomainLabel(String url) {
    var withoutProto = url.trim();
    if (withoutProto.startsWith('https://')) {
      withoutProto = withoutProto.substring(8);
    } else if (withoutProto.startsWith('http://')) {
      withoutProto = withoutProto.substring(7);
    }
    final host = withoutProto.split(RegExp(r'[/:?#]')).first.trim();
    if (host.isEmpty) return null;
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host)) return null;

    final parts = host.split('.');
    if (parts.length < 2) return null;

    String mainPart;
    if (parts.length >= 3 &&
        (parts[parts.length - 2] == 'co' || parts[parts.length - 2] == 'com')) {
      mainPart = parts[parts.length - 3];
    } else {
      mainPart = parts[parts.length - 2];
    }
    if (mainPart.isEmpty ||
        mainPart == 'www' ||
        mainPart == 'api' ||
        mainPart == 'cdn') {
      return null;
    }

    return mainPart
        .split(RegExp(r'[-_]'))
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .where((word) => word.isNotEmpty)
        .join(' ');
  }

  /// Builds the source label of an addon stream.
  static String detectStreamHost({
    required String addonName,
    required String streamName,
    required String url,
  }) {
    final labels = <String>[];
    for (final line in streamName.split('\n')) {
      final trimmed = line.trim().replaceAll(
        RegExp(r'^[\[\]\(\)\s]+|[\[\]\(\)\s]+$'),
        '',
      );
      if (trimmed.isEmpty) continue;
      if (trimmed.toLowerCase() == addonName.toLowerCase()) continue;
      if (labels.contains(trimmed)) continue;
      labels.add(trimmed);
    }

    final domainLabel = extractDomainLabel(url);
    if (domainLabel != null &&
        domainLabel.toLowerCase() != addonName.toLowerCase() &&
        !labels.any((l) => l.toLowerCase() == domainLabel.toLowerCase())) {
      labels.add(domainLabel);
    }

    if (labels.isNotEmpty) return '$addonName · ${labels.first}';
    return addonName;
  }

  /// Parses a `SxxExx` style marker from free text.
  static (int, int)? parseSeasonEpisode(String text) {
    final bytes = text.codeUnits;
    var index = 0;
    while (index < bytes.length) {
      final code = bytes[index];
      if ((code == 0x53 || code == 0x73) &&
          index + 1 < bytes.length &&
          _isDigit(bytes[index + 1])) {
        final previous = index == 0 ? null : bytes[index - 1];
        if (previous == null || !_isAlphanumeric(previous)) {
          final seasonStart = index + 1;
          var seasonEnd = seasonStart;
          while (seasonEnd < bytes.length && _isDigit(bytes[seasonEnd])) {
            seasonEnd++;
          }
          if (seasonEnd < bytes.length && (seasonEnd - seasonStart) <= 3) {
            final season = int.tryParse(text.substring(seasonStart, seasonEnd));
            var episodeIndex = seasonEnd;
            while (episodeIndex < bytes.length &&
                const [0x2E, 0x20, 0x5F, 0x2D].contains(bytes[episodeIndex])) {
              episodeIndex++;
            }
            if (episodeIndex < bytes.length &&
                (bytes[episodeIndex] == 0x45 || bytes[episodeIndex] == 0x65) &&
                episodeIndex + 1 < bytes.length &&
                _isDigit(bytes[episodeIndex + 1])) {
              final episodeStart = episodeIndex + 1;
              var episodeEnd = episodeStart;
              while (episodeEnd < bytes.length && _isDigit(bytes[episodeEnd])) {
                episodeEnd++;
              }
              if ((episodeEnd - episodeStart) <= 4) {
                final episode = int.tryParse(
                  text.substring(episodeStart, episodeEnd),
                );
                if (season != null && episode != null) return (season, episode);
              }
            }
          }
        }
      }

      if ((code == 0x78 || code == 0x58) &&
          index > 0 &&
          _isDigit(bytes[index - 1]) &&
          index + 1 < bytes.length &&
          _isDigit(bytes[index + 1])) {
        var seasonStart = index - 1;
        while (seasonStart > 0 && _isDigit(bytes[seasonStart - 1])) {
          seasonStart--;
        }
        if (seasonStart == 0 || !_isAlphanumeric(bytes[seasonStart - 1])) {
          final seasonText = text.substring(seasonStart, index);
          var episodeEnd = index + 1;
          while (episodeEnd < bytes.length && _isDigit(bytes[episodeEnd])) {
            episodeEnd++;
          }
          final episodeText = text.substring(index + 1, episodeEnd);
          final season = int.tryParse(seasonText);
          final episode = int.tryParse(episodeText);
          if (seasonText.length <= 3 &&
              episodeText.length <= 4 &&
              season != null &&
              episode != null &&
              season > 0 &&
              season < 100 &&
              episode > 0 &&
              episode < 10000) {
            return (season, episode);
          }
        }
      }
      index++;
    }

    final upper = text.toUpperCase();
    final seasonPosition = upper.indexOf('SEASON ');
    if (seasonPosition >= 0) {
      final afterSeason = upper.substring(seasonPosition + 7);
      final seasonDigits = afterSeason
          .replaceFirst(RegExp(r'^ +'), '')
          .split('')
          .takeWhile((c) => _isDigit(c.codeUnitAt(0)))
          .join();
      final season = int.tryParse(seasonDigits);
      final episodePosition = upper.indexOf('EPISODE ');
      if (season != null && episodePosition >= 0) {
        final afterEpisode = upper.substring(episodePosition + 8);
        final episodeDigits = afterEpisode
            .replaceFirst(RegExp(r'^ +'), '')
            .split('')
            .takeWhile((c) => _isDigit(c.codeUnitAt(0)))
            .join();
        final episode = int.tryParse(episodeDigits);
        if (episode != null) return (season, episode);
      }
    }

    final episodeOnly = upper.indexOf('EPISODE ');
    if (episodeOnly >= 0) {
      final after = upper.substring(episodeOnly + 8);
      final digits = after
          .replaceFirst(RegExp(r'^ +'), '')
          .split('')
          .takeWhile((c) => _isDigit(c.codeUnitAt(0)))
          .join();
      final episode = int.tryParse(digits);
      if (episode != null) return (1, episode);
    }

    return null;
  }

  /// Converts an addon stream into a playable release.
  static Release? streamItemToRelease(
    String addonName,
    StreamItem stream, {
    required int season,
    required int episode,
  }) {
    final url = stream.url?.trim();
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;

    final streamName = stream.name ?? '';
    final title = stream.title ?? '';
    final description = stream.description ?? '';
    final combined = '$streamName $title $description';

    if (season > 0 && episode > 0) {
      final parsed = parseSeasonEpisode(combined);
      if (parsed != null && (parsed.$1 != season || parsed.$2 != episode)) {
        return null;
      }
    }

    final quality = parseQuality(combined);
    final codec = parseCodec(combined);
    final language = parseAudioTracks(combined);

    final sizeBytes =
        stream.behaviorHints?.videoSize ?? parseSizeBytes(combined);

    final rawFilename = _firstLine(title).isNotEmpty
        ? _firstLine(title)
        : (_firstLine(description).isNotEmpty
              ? _firstLine(description)
              : (_firstLine(streamName).isNotEmpty
                    ? _firstLine(streamName)
                    : '$addonName Stream'));
    final filename = cleanStreamText(rawFilename);

    final sourceLabel = cleanStreamText(
      detectStreamHost(addonName: addonName, streamName: streamName, url: url),
    );

    final headers = <MapEntry<String, String>>[];
    final hints = stream.behaviorHints;
    if (hints != null) {
      const allowed = {
        'user-agent',
        'referer',
        'origin',
        'range',
        'x-forwarded-for',
        'accept',
        'accept-language',
      };
      hints.headers.forEach((key, value) {
        if (allowed.contains(key.toLowerCase())) {
          headers.add(MapEntry(key, value));
        }
      });
    }

    return Release(
      provider: ProviderKind.addons,
      filename: filename,
      quality: quality,
      codec: codec,
      language: language,
      sizeBytes: sizeBytes,
      season: season > 0 ? season : null,
      episode: episode > 0 ? episode : null,
      mirrors: [
        SourceMirror(
          label: sourceLabel,
          resolverUrl: url,
          headers: headers,
          directFile: true,
        ),
      ],
    );
  }

  /// Converts a release into a playable source.
  static PlaybackSource? releaseToPlaybackSource(Release release) {
    if (release.mirrors.isEmpty) return null;
    final mirror = release.mirrors.first;
    return PlaybackSource(
      provider: ProviderKind.addons,
      url: mirror.resolverUrl,
      headers: mirror.headers,
      sourceLabel: mirror.label,
    );
  }

  static String _firstLine(String value) {
    if (value.isEmpty) return '';
    return value.split('\n').first.trim();
  }

  static bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

  static bool _isAlphanumeric(int code) =>
      _isDigit(code) ||
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A);
}
