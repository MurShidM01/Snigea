import 'provider_kind.dart';

/// Whether a title is a movie or a series.
enum MediaType {
  movie('movie'),
  series('series');

  const MediaType(this.wireName);

  /// Value used by providers that expect `movie` / `series` identifiers.
  final String wireName;

  /// Parses a wire value, defaulting to [MediaType.movie].
  static MediaType fromWire(String? value) =>
      value?.toLowerCase() == 'series' ? MediaType.series : MediaType.movie;
}

/// A provider scoped identifier for a title.
class ProviderMediaId {
  const ProviderMediaId({required this.provider, required this.value});

  final ProviderKind provider;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is ProviderMediaId &&
      other.provider == provider &&
      other.value == value;

  @override
  int get hashCode => Object.hash(provider, value);

  @override
  String toString() => '${provider.cacheKey}::$value';
}

/// A single entry of a provider catalogue.
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.title,
    required this.mediaType,
    this.year,
    this.posterUrl,
    this.seasonCount,
  });

  final ProviderMediaId id;
  final String title;
  final MediaType mediaType;
  final String? year;
  final String? posterUrl;
  final int? seasonCount;

  bool get isSeries => mediaType == MediaType.series;
}

/// One episode inside a season.
class Episode {
  const Episode({
    required this.season,
    required this.number,
    this.title,
    this.overview,
  });

  final int season;
  final int number;
  final String? title;
  final String? overview;

  /// Label used by the UI, e.g. `E04`.
  String get code => 'E${number.toString().padLeft(2, '0')}';
}

/// A season of a series.
class Season {
  const Season({required this.number, required this.episodes});

  final int number;
  final List<Episode> episodes;

  /// Label used by the UI, e.g. `Season 2`.
  String get label => 'Season $number';
}

/// An alternative audio track (a "dub") pointing at a sibling subject id.
class AudioTrackOption {
  const AudioTrackOption({
    required this.subjectId,
    required this.language,
    required this.label,
  });

  final String subjectId;
  final String language;
  final String label;
}

/// Full metadata for a title.
class MediaDetails {
  const MediaDetails({
    required this.id,
    required this.title,
    required this.mediaType,
    this.year,
    this.description,
    this.tagline,
    this.imdbRating,
    this.director,
    this.stars,
    this.prints,
    this.audios,
    this.posterUrl,
    this.duration,
    this.genres = const [],
    this.seasons = const [],
    this.dubs = const [],
  });

  final ProviderMediaId id;
  final String title;
  final MediaType mediaType;
  final String? year;
  final String? description;
  final String? tagline;
  final String? imdbRating;
  final String? director;
  final String? stars;
  final String? prints;
  final String? audios;
  final String? posterUrl;
  final String? duration;
  final List<String> genres;
  final List<Season> seasons;
  final List<AudioTrackOption> dubs;

  bool get isSeries => mediaType == MediaType.series || seasons.isNotEmpty;

  bool get hasLanguages => dubs.length > 1;

  /// All subject ids that belong to the same title (main + dub variants).
  List<String> siblingIds() {
    final ids = <String>{id.value};
    for (final dub in dubs) {
      if (dub.subjectId.isNotEmpty) ids.add(dub.subjectId);
    }
    final sorted = ids.toList()..sort();
    return sorted;
  }
}

/// An external subtitle track.
class SubtitleOption {
  const SubtitleOption({required this.name, required this.url});

  final String name;
  final String url;
}

/// Browse ranking metrics attached to a catalogue item.
class BrowseMetrics {
  const BrowseMetrics({
    this.trending,
    this.rating,
    this.recentRating,
    this.popularity,
  });

  final double? trending;
  final double? rating;
  final double? recentRating;
  final double? popularity;

  /// Merges two metric sets, keeping the first non-null value.
  BrowseMetrics merge(BrowseMetrics other) => BrowseMetrics(
    trending: trending ?? other.trending,
    rating: rating ?? other.rating,
    recentRating: recentRating ?? other.recentRating,
    popularity: popularity ?? other.popularity,
  );
}

/// The ranking preset used by the discovery screen.
enum BrowsePreset {
  trending('Trending Now', 'trending'),
  topRated('Top Rated', 'rating'),
  recentRatings('Top Rated (Recent)', 'recentRating'),
  mostWatched('Most Watched', 'popularity');

  const BrowsePreset(this.label, this.metricKey);

  final String label;
  final String metricKey;
}
