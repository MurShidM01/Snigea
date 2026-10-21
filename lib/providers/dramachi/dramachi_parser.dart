import '../../core/json/json_utils.dart';
import '../../core/text/cleaners.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';

/// Parsing helpers for the Dramachi provider.
///
/// The API is a small JSON interface with `search`, `title_v2`, `eplist` and
/// `getFile` endpoints; the rules below mirror the reference implementation.
abstract final class DramachiParser {
  /// The base address of the Dramachi API.
  static const String defaultBaseUrl = 'https://api.nodeobjects.com/';

  /// The CDN prefix used for poster artwork.
  static const String imageCdnBase =
      'https://static.nodeobjects.com/thumbnail/';

  /// Converts a search response into catalogue entries.
  static List<CatalogItem> searchToCatalog(Object? payload) {
    final map = asMap(payload);
    final items = asList(map?['data']) ?? const [];
    final results = <CatalogItem>[];

    for (final entry in items) {
      final item = asMap(entry);
      if (item == null) continue;
      final id = asString(item['id']);
      if (id == null || id.isEmpty) continue;

      final content = asString(item['content']);
      final isMovie =
          content != null &&
          (content.toLowerCase() == 'movies' ||
              content.toLowerCase() == 'movie');

      final thumb = asString(item['thumb'])?.trim();
      final posterUrl = (thumb == null || thumb.isEmpty)
          ? null
          : '$imageCdnBase$thumb';

      final year = asString(item['year'])?.trim();

      results.add(
        CatalogItem(
          id: ProviderMediaId(provider: ProviderKind.dramachi, value: id),
          title: asString(item['title']) ?? 'Unknown',
          mediaType: isMovie ? MediaType.movie : MediaType.series,
          year: (year == null || year.isEmpty) ? null : year,
          posterUrl: posterUrl,
        ),
      );
    }
    return results;
  }

  /// Extracts the season number of a season key such as `Season 01`.
  static int? extractLeadingSeasonNumber(String name) {
    final lower = name.toLowerCase();
    if (!lower.startsWith('season')) return null;
    final after = lower.substring('season'.length).trim();
    final digits = after.split('').takeWhile((c) {
      final code = c.codeUnitAt(0);
      return code >= 0x30 && code <= 0x39;
    }).join();
    return int.tryParse(digits);
  }

  /// Parses the episode number out of a raw episode title.
  static int? parseEpisodeNumber(String fileTitle) {
    final cleaned = cleanEpisodeTitle(fileTitle);
    final upper = cleaned.toUpperCase();

    for (final prefix in const ['EPISODE', 'EP.', 'EP', 'E']) {
      var searchFrom = 0;
      while (searchFrom < upper.length) {
        final relPosition = upper.indexOf(prefix, searchFrom);
        if (relPosition < 0) break;
        final position = relPosition;
        if (position + prefix.length > upper.length) break;
        final prevChar = position > 0 ? upper[position - 1] : null;
        final validBoundary =
            prevChar == null ||
            !_isAlphabetic(prevChar) ||
            (prefix == 'E' && _isDigit(prevChar));
        final after = upper.substring(position + prefix.length);
        final afterTrimmed = after.replaceFirst(RegExp(r'^[ \-._]+'), '');
        final digits = afterTrimmed.split('').takeWhile((c) {
          final code = c.codeUnitAt(0);
          return code >= 0x30 && code <= 0x39;
        }).join();
        if (validBoundary && digits.isNotEmpty) {
          final parsed = int.tryParse(digits);
          if (parsed != null) return parsed;
        }
        searchFrom = position + prefix.length;
      }
    }

    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      final parsed = int.tryParse(parts.last);
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Removes the quality / language suffixes from an episode title.
  static String cleanEpisodeTitle(String fileTitle) {
    var title = fileTitle.trim();
    for (final suffix in const [
      ' 720p',
      ' 1080p',
      ' 540p',
      ' 480p',
      ' 360p',
      ' DUB',
      ' hi DUB',
      ' ENG Subbed Full',
    ]) {
      if (title.endsWith(suffix)) {
        title = title.substring(0, title.length - suffix.length);
      }
    }
    return title;
  }

  /// Builds the catalogue entry of a single episode.
  static Episode toEpisode(int season, int index, String fileTitle) {
    final number = parseEpisodeNumber(fileTitle) ?? index + 1;
    return Episode(
      season: season,
      number: number,
      title: cleanEpisodeTitle(fileTitle),
    );
  }

  /// Converts a resource entry into a release.
  static Release toRelease({
    required String filename,
    required String url,
    String? quality,
    String? size,
    int? season,
    int? episode,
    String? resourceId,
  }) {
    return Release(
      provider: ProviderKind.dramachi,
      filename: filename,
      quality: (quality == null || quality.isEmpty) ? null : quality,
      codec: null,
      language: null,
      sizeBytes: size == null ? null : parseSizeBytes(size),
      season: season,
      episode: episode,
      mirrors: [
        SourceMirror(
          label: 'Dramachi CDN',
          resolverUrl: url,
          headers: const [],
          directFile: true,
        ),
      ],
      resourceId: resourceId,
    );
  }

  static bool _isAlphabetic(String character) {
    final code = character.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  }

  static bool _isDigit(String character) {
    final code = character.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}
