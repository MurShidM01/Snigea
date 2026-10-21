import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../core/text/cleaners.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';

/// Raised when a 4KHDHub page cannot be understood.
class FourKHdHubParseException implements Exception {
  const FourKHdHubParseException(this.message);

  final String message;

  @override
  String toString() => 'FourKHdHubParseException: $message';
}

/// HTML parsing for the 4KHDHub provider.
///
/// The site is a plain server rendered WordPress theme, so the rules below
/// mirror the reference scraper: cards, metadata blocks, episode rows and
/// mirror links are located by class name.
abstract final class FourKHdHubParser {
  /// The language names that are recognised in a release name.
  static const Map<String, String> _languagePatterns = <String, String>{
    'hindi': 'Hindi',
    'hin': 'Hindi',
    'english': 'English',
    'eng': 'English',
    'tamil': 'Tamil',
    'tam': 'Tamil',
    'telugu': 'Telugu',
    'tel': 'Telugu',
    'kannada': 'Kannada',
    'kan': 'Kannada',
    'malayalam': 'Malayalam',
    'mal': 'Malayalam',
    'bengali': 'Bengali',
    'ben': 'Bengali',
    'bangla': 'Bengali',
    'marathi': 'Marathi',
    'mar': 'Marathi',
    'punjabi': 'Punjabi',
    'pan': 'Punjabi',
    'pun': 'Punjabi',
    'gujarati': 'Gujarati',
    'guj': 'Gujarati',
    'urdu': 'Urdu',
    'urd': 'Urdu',
    'japanese': 'Japanese',
    'jap': 'Japanese',
    'jpn': 'Japanese',
    'korean': 'Korean',
    'kor': 'Korean',
    'chinese': 'Chinese',
    'chi': 'Chinese',
    'mandarin': 'Chinese',
    'cantonese': 'Chinese',
    'spanish': 'Spanish',
    'spa': 'Spanish',
    'esp': 'Spanish',
    'castilian': 'Spanish',
    'french': 'French',
    'fre': 'French',
    'fra': 'French',
    'german': 'German',
    'ger': 'German',
    'deu': 'German',
    'italian': 'Italian',
    'ita': 'Italian',
    'portuguese': 'Portuguese',
    'por': 'Portuguese',
    'russian': 'Russian',
    'rus': 'Russian',
    'arabic': 'Arabic',
    'ara': 'Arabic',
    'turkish': 'Turkish',
    'tur': 'Turkish',
    'thai': 'Thai',
    'indonesian': 'Indonesian',
    'ind': 'Indonesian',
    'vietnamese': 'Vietnamese',
    'vie': 'Vietnamese',
    'polish': 'Polish',
    'pol': 'Polish',
    'dutch': 'Dutch',
    'dut': 'Dutch',
    'nld': 'Dutch',
    'swedish': 'Swedish',
    'swe': 'Swedish',
    'danish': 'Danish',
    'dan': 'Danish',
    'norwegian': 'Norwegian',
    'nor': 'Norwegian',
    'finnish': 'Finnish',
    'fin': 'Finnish',
  };
  static const String _cardSelector = 'a.movie-card';
  static const String _titleSelector = '.movie-card-title';
  static const String _metaSelector = '.movie-card-meta';
  static const String _h1Selector = 'h1';
  static const String _contentDescSelector = '.content-section p.mt-4';
  static const String _taglineSelector = '.movie-tagline';
  static const String _imdbSelector = '.imdb-score';
  static const String _badgeAnchorSelector = '.badge-outline a';
  static const String _metadataItemSelector = '.metadata-item';
  static const String _metadataLabelSelector = '.metadata-label';
  static const String _metadataValueSelector = '.metadata-value';
  static const String _episodeItemSelector = '#episodes .episode-download-item';
  static const String _downloadItemSelector = '.download-item';
  static const String _episodeFileTitleSelector = '.episode-file-title';
  static const String _fileTitleSelector = '.file-title';
  static const String _linkSelector = 'a[href]';
  static const String _badgeSizeSelector = '.badge-size, .badge';
  static const String _ogImageSelector = 'meta[property="og:image"]';
  static const String _ogTitleSelector = 'meta[property="og:title"]';
  static const String _metaDescriptionSelector = 'meta[name="description"]';

  /// Parses the search results page.
  static List<CatalogItem> parseSearch(String baseUrl, String html) {
    final document = html_parser.parse(html);
    final base = Uri.tryParse(baseUrl);
    final items = <CatalogItem>[];

    for (final node in document.querySelectorAll(_cardSelector)) {
      final href = node.attributes['href'];
      if (href == null) continue;
      final url = base == null ? Uri.tryParse(href) : base.resolve(href);
      if (url == null) continue;
      if (base != null && url.host != base.host) continue;

      final title = _textOf(node.querySelector(_titleSelector));
      if (title.isEmpty) continue;

      final metaText = _textOf(node.querySelector(_metaSelector));
      final year = _firstFourDigitYear(metaText);
      final mediaType = href.contains('-series-')
          ? MediaType.series
          : MediaType.movie;

      final image = node.querySelector('img');
      final posterUrl = image?.attributes['src'];

      items.add(
        CatalogItem(
          id: ProviderMediaId(
            provider: ProviderKind.fourkhdhub,
            value: url.path,
          ),
          title: title,
          mediaType: mediaType,
          year: year,
          posterUrl: posterUrl,
          seasonCount: _parseSeasonCount(metaText),
        ),
      );
    }
    return items;
  }

  /// Parses a title page.
  static MediaDetails parseDetails(String id, String html) {
    final document = html_parser.parse(html);

    final h1 = document.querySelector(_h1Selector);
    final rawTitle = (h1 == null ? '' : _textOf(h1)).isNotEmpty
        ? _textOf(h1)
        : (_metaContent(document, _ogTitleSelector) ?? '');
    if (rawTitle.isEmpty) {
      throw const FourKHdHubParseException('title missing');
    }

    final title = stripTrailingYear(rawTitle);
    final mediaType = id.contains('-series-')
        ? MediaType.series
        : MediaType.movie;

    final description =
        _textOf(document.querySelector(_contentDescSelector)).isNotEmpty
        ? _textOf(document.querySelector(_contentDescSelector))
        : _metaContent(document, _metaDescriptionSelector);

    final tagline = _nullableText(document.querySelector(_taglineSelector));
    final imdbRating = _nullableText(document.querySelector(_imdbSelector));
    final posterUrl = _metaContent(document, _ogImageSelector);

    final year =
        _firstFourDigitYear(_findMetadata(document, 'Release:') ?? '') ??
        _firstFourDigitYear(_findMetadata(document, 'Last Air:') ?? '') ??
        _firstFourDigitYear(rawTitle);

    final genres = document
        .querySelectorAll(_badgeAnchorSelector)
        .map(_textOf)
        .where(isGenre)
        .toList();

    final seasons = _parseSeasons(document);

    return MediaDetails(
      id: ProviderMediaId(provider: ProviderKind.fourkhdhub, value: id),
      title: title,
      mediaType: mediaType,
      year: year,
      description: description?.isEmpty == true ? null : description,
      tagline: tagline,
      imdbRating: imdbRating,
      director: _findMetadata(document, 'Director:'),
      stars: _findMetadata(document, 'Stars:'),
      prints:
          _findMetadata(document, 'Prints:') ??
          _findMetadata(document, 'Print:'),
      audios: _findMetadata(document, 'Audios:'),
      posterUrl: posterUrl,
      duration: null,
      genres: genres,
      seasons: seasons,
      dubs: const [],
    );
  }

  /// Parses the download / episode rows of a title page.
  static List<Release> parseReleases(
    String html, {
    required int season,
    required int episode,
  }) {
    final document = html_parser.parse(html);
    final itemSelector = season > 0
        ? _episodeItemSelector
        : _downloadItemSelector;
    final filenameSelector = season > 0
        ? _episodeFileTitleSelector
        : _fileTitleSelector;

    final pageLanguage = _findMetadata(document, 'Audios:') != null
        ? _normalizeLanguageLabel(_findMetadata(document, 'Audios:')!)
        : null;

    final grouped = <String, Release>{};

    for (final item in document.querySelectorAll(itemSelector)) {
      final filename = _textOf(item.querySelector(filenameSelector));
      if (filename.isEmpty || _isArchive(filename)) continue;

      final parsedEpisode = parseSeasonEpisode(filename);
      if (season > 0 && parsedEpisode != (season, episode)) continue;

      final mirrors = <SourceMirror>[];
      for (final link in item.querySelectorAll(_linkSelector)) {
        final href = link.attributes['href'];
        if (href == null) continue;
        if (!href.startsWith('https://') || href.contains('logout')) continue;
        final label = _textOf(link);
        mirrors.add(
          SourceMirror(
            label: label.isEmpty ? 'Source' : label,
            resolverUrl: href,
            headers: const [],
            directFile:
                !href.contains('hubcloud.') &&
                !href.contains('hubdrive.') &&
                !href.contains('greenmotors.') &&
                !href.contains('greenmountmotors.'),
          ),
        );
      }
      if (mirrors.isEmpty) continue;

      final sizeText = item
          .querySelectorAll(_badgeSizeSelector)
          .map(_textOf)
          .firstWhere((text) => parseSizeBytes(text) != null, orElse: () => '');

      final key = _normalizeFilename(filename);
      grouped.putIfAbsent(
        key,
        () => Release(
          provider: ProviderKind.fourkhdhub,
          filename: filename,
          quality: detectQuality(filename),
          codec: detectCodec(filename),
          language: detectLanguage(filename) ?? pageLanguage,
          sizeBytes: sizeText.isEmpty ? null : parseSizeBytes(sizeText),
          season: parsedEpisode?.$1,
          episode: parsedEpisode?.$2,
          mirrors: const [],
        ),
      );

      for (final mirror in mirrors) {
        final current = grouped[key]!;
        final exists = current.mirrors.any(
          (existing) => existing.resolverUrl == mirror.resolverUrl,
        );
        if (!exists) {
          grouped[key] = current.copyWith(
            mirrors: [...current.mirrors, mirror],
          );
        }
      }
    }

    final releases = grouped.values.toList();
    releases.sort((left, right) {
      final byResolution = right.resolutionU64.compareTo(left.resolutionU64);
      if (byResolution != 0) return byResolution;
      return (right.sizeBytes ?? 0).compareTo(left.sizeBytes ?? 0);
    });
    return releases;
  }

  static List<Season> _parseSeasons(dom.Document document) {
    final seasons = <int, Map<int, Episode>>{};
    for (final node in document.querySelectorAll(_episodeItemSelector)) {
      final filename = _textOf(node.querySelector(_episodeFileTitleSelector));
      final parsed = parseSeasonEpisode(filename);
      if (parsed == null) continue;
      final (season, episode) = parsed;
      seasons
          .putIfAbsent(season, () => <int, Episode>{})
          .putIfAbsent(episode, () => Episode(season: season, number: episode));
    }
    final result = <Season>[];
    final keys = seasons.keys.toList()..sort();
    for (final key in keys) {
      final episodes = seasons[key]!.values.toList()
        ..sort((a, b) => a.number.compareTo(b.number));
      result.add(Season(number: key, episodes: episodes));
    }
    return result;
  }

  // --------------------------------------------------------------- helpers

  static String _textOf(dom.Element? element) {
    if (element == null) return '';
    return element.text
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .join(' ');
  }

  static String? _nullableText(dom.Element? element) {
    if (element == null) return null;
    final text = _textOf(element);
    return text.isEmpty ? null : text;
  }

  static String? _metaContent(dom.Document document, String selector) {
    final node = document.querySelector(selector);
    final content = node?.attributes['content'];
    return (content == null || content.isEmpty) ? null : content;
  }

  static String? _findMetadata(dom.Document document, String label) {
    for (final node in document.querySelectorAll(_metadataItemSelector)) {
      final current = _textOf(node.querySelector(_metadataLabelSelector));
      if (current == label) {
        final value = _textOf(node.querySelector(_metadataValueSelector));
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  static String? _firstFourDigitYear(String value) {
    final year = extract4DigitYear(value);
    return year.isEmpty ? null : year;
  }

  static bool isGenre(String value) {
    const genres = {
      'action',
      'adventure',
      'animation',
      'comedy',
      'crime',
      'documentary',
      'drama',
      'family',
      'fantasy',
      'history',
      'horror',
      'music',
      'mystery',
      'romance',
      'science fiction',
      'sci-fi',
      'thriller',
      'war',
      'western',
    };
    return genres.contains(value.toLowerCase());
  }

  /// Removes a trailing parenthesised year from a title.
  static String stripTrailingYear(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 6) return trimmed;
    final start = trimmed.length - 6;
    final isParenthesizedYear =
        trimmed[start] == '(' &&
        trimmed[trimmed.length - 1] == ')' &&
        trimmed
            .substring(start + 1, trimmed.length - 1)
            .split('')
            .every((c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39);
    if (isParenthesizedYear) {
      return trimmed.substring(0, start).trimRight();
    }
    return trimmed;
  }

  static int? _parseSeasonCount(String value) {
    final marker = value.indexOf('S');
    if (marker < 0) return null;
    final suffix = value.substring(marker);
    int? max;
    for (final part in suffix.split(RegExp(r'[- •]'))) {
      if (!part.startsWith('S')) continue;
      final parsed = int.tryParse(part.substring(1));
      if (parsed == null) continue;
      if (max == null || parsed > max) max = parsed;
    }
    return max;
  }

  /// Parses a `SxxExx` marker from a filename.
  static (int, int)? parseSeasonEpisode(String value) {
    final upper = value.toUpperCase();
    for (var index = 0; index + 4 < upper.length; index++) {
      if (upper.codeUnitAt(index) != 0x53) continue; // 'S'
      var seasonEnd = index + 1;
      while (seasonEnd < upper.length &&
          upper.codeUnitAt(seasonEnd) >= 0x30 &&
          upper.codeUnitAt(seasonEnd) <= 0x39) {
        seasonEnd++;
      }
      if (seasonEnd == index + 1) continue;
      if (seasonEnd >= upper.length || upper.codeUnitAt(seasonEnd) != 0x45) {
        continue; // 'E'
      }
      var episodeEnd = seasonEnd + 1;
      while (episodeEnd < upper.length &&
          upper.codeUnitAt(episodeEnd) >= 0x30 &&
          upper.codeUnitAt(episodeEnd) <= 0x39) {
        episodeEnd++;
      }
      if (episodeEnd == seasonEnd + 1) continue;
      final season = int.tryParse(upper.substring(index + 1, seasonEnd));
      final episode = int.tryParse(upper.substring(seasonEnd + 1, episodeEnd));
      if (season != null && episode != null) return (season, episode);
    }
    return null;
  }

  /// Detects the advertised resolution of a release name.
  static String? detectQuality(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('2160p') ||
        lower.contains('2160') ||
        lower.contains('4k') ||
        lower.contains('uhd')) {
      return '2160p';
    }
    if (lower.contains('1080p') ||
        lower.contains('1080') ||
        lower.contains('fhd')) {
      return '1080p';
    }
    if (lower.contains('720p') ||
        lower.contains('720') ||
        lower.contains('hd')) {
      return '720p';
    }
    if (lower.contains('480p') ||
        lower.contains('480') ||
        lower.contains('sd')) {
      return '480p';
    }
    return null;
  }

  /// Detects the codec advertised by a release name.
  static String? detectCodec(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('av1')) return 'AV1';
    if (lower.contains('h.265') ||
        lower.contains('h265') ||
        lower.contains('x265')) {
      return 'H.265';
    }
    if (lower.contains('hevc')) return 'HEVC';
    if (lower.contains('h.264') ||
        lower.contains('h264') ||
        lower.contains('x264')) {
      return 'H.264';
    }
    if (lower.contains('remux')) return 'REMUX';
    return null;
  }

  /// Detects the languages advertised by a release name.
  static String? detectLanguage(String value) {
    final lower = value.toLowerCase();
    final languages = detectLanguages(value);
    if (languages.isNotEmpty) return languages.join(', ');

    if (lower.contains('multi audio') || lower.contains('multi-audio')) {
      return 'Multi Audio';
    }
    if (lower.contains('dual audio') || lower.contains('dual-audio')) {
      return 'Dual Audio';
    }
    return null;
  }

  /// Detects every language that is advertised in [value].
  ///
  /// A release can carry several audio tracks, for example a dual audio
  /// release with an English and a Hindi track, so every match is reported.
  static List<String> detectLanguages(String value) {
    final lower = value.toLowerCase();
    final found = <String>[];
    _languagePatterns.forEach((pattern, label) {
      if (_containsWord(lower, pattern) && !found.contains(label)) {
        found.add(label);
      }
    });
    return found;
  }

  /// True when [value] contains [needle] as a whole word.
  static bool _containsWord(String value, String needle) {
    var index = 0;
    while (index <= value.length) {
      final position = value.indexOf(needle, index);
      if (position < 0) return false;
      final end = position + needle.length;
      final beforeOk =
          position == 0 || !_isAlphabetic(value.codeUnitAt(position - 1));
      final afterOk =
          end >= value.length || !_isAlphabetic(value.codeUnitAt(end));
      if (beforeOk && afterOk) return true;
      index = position + 1;
    }
    return false;
  }

  static bool _isAlphabetic(int codeUnit) {
    return (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7A);
  }

  static String? _normalizeLanguageLabel(String value) {
    // The page metadata can list several audio tracks, for example
    // "English, Hindi"; every language is kept.
    final languages = detectLanguages(value);
    if (languages.isNotEmpty) return languages.join(', ');
    final joined = value
        .split(RegExp(r'[|/+,\]]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
    if (joined.isEmpty ||
        joined.length > 80 ||
        const {'n/a', 'na', 'unknown'}.contains(joined.toLowerCase())) {
      return null;
    }
    return joined;
  }

  static bool _isArchive(String value) {
    final lower = value.toLowerCase();
    return lower.endsWith('.zip') ||
        lower.contains('complete season') ||
        lower.contains('season pack');
  }

  static String _normalizeFilename(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
