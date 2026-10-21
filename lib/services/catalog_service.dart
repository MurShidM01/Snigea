// The constructors below use public named parameters that are assigned to
// private fields. Dart does not allow private named parameters, therefore the
// `prefer_initializing_formals` hint does not apply here.
// ignore_for_file: prefer_initializing_formals

import '../core/crypto/digest.dart';
import '../data/models/media.dart';
import '../data/models/provider_kind.dart';
import '../data/repositories/settings_repository.dart';

/// The catalogue service.
///
/// It hides the provider differences behind a single API, applies the
/// metadata cache and provides the provider configuration.
class CatalogService {
  CatalogService({
    required MetadataCacheRepository cache,
    required Future<Map<ProviderKind, ProviderSettings>> Function()
    providerConfigs,
  }) : _cache = cache,
       _providerConfigs = providerConfigs;

  final MetadataCacheRepository _cache;
  final Future<Map<ProviderKind, ProviderSettings>> Function() _providerConfigs;

  /// The cache key of a details payload.
  static String detailsCacheKey(ProviderKind provider, String id) =>
      'details:${provider.cacheKey}:$id';

  /// The cache key of a search payload.
  static String searchCacheKey(ProviderKind provider, String query, int page) =>
      'search:${provider.cacheKey}:${md5Hex(query.toLowerCase())}:$page';

  /// The cache key of a homepage payload.
  static String homeCacheKey(ProviderKind provider, String tabId, int page) =>
      'home:${provider.cacheKey}:$tabId:$page';

  /// Loads the details of a title, using the cache when possible.
  Future<MediaDetails> details({
    required ProviderKind provider,
    required String id,
    required Future<MediaDetails> Function() loader,
  }) async {
    final key = detailsCacheKey(provider, id);
    final cached = await _cache.readJson(key);
    if (cached is Map) {
      try {
        return MediaDetailsBridge.fromJson(
          cached.cast<String, Object?>(),
          provider,
        );
      } catch (_) {
        await _cache.remove(key);
      }
    }
    final details = await loader();
    await _cache.write(
      cacheKey: key,
      provider: provider,
      subjectId: id,
      payload: MediaDetailsBridge.toJson(details),
      ttl: const Duration(hours: 24),
    );
    return details;
  }

  /// Stores a raw provider payload in the metadata cache.
  Future<void> cachePayload({
    required String cacheKey,
    required ProviderKind provider,
    required String subjectId,
    required Object payload,
    Duration ttl = const Duration(hours: 24),
  }) => _cache.write(
    cacheKey: cacheKey,
    provider: provider,
    subjectId: subjectId,
    payload: payload,
    ttl: ttl,
  );

  /// Reads a raw provider payload from the metadata cache.
  Future<Object?> cachedPayload(String cacheKey) => _cache.readJson(cacheKey);

  /// Removes expired cache entries.
  Future<void> prune() => _cache.prune();

  /// The providers that are enabled, honouring the stored configuration.
  Future<List<ProviderKind>> enabledProviders() async {
    final configs = await _providerConfigs();
    return ProviderKind.values
        .where((provider) => configs[provider]?.enabled ?? false)
        .toList();
  }
}

/// Converts between the domain model and a JSON payload.
///
/// The metadata cache stores a provider independent representation so that a
/// cached entry can be restored by any provider.
abstract final class MediaDetailsBridge {
  /// Serialises a details object for the cache.
  static Map<String, Object?> toJson(MediaDetails details) => {
    'id': details.id.value,
    'title': details.title,
    'media_type': details.mediaType.wireName,
    'year': details.year,
    'description': details.description,
    'tagline': details.tagline,
    'imdb_rating': details.imdbRating,
    'director': details.director,
    'stars': details.stars,
    'prints': details.prints,
    'audios': details.audios,
    'poster_url': details.posterUrl,
    'duration': details.duration,
    'genres': details.genres,
    'seasons': details.seasons
        .map(
          (season) => {
            'number': season.number,
            'episodes': season.episodes
                .map(
                  (episode) => {
                    'season': episode.season,
                    'number': episode.number,
                    'title': episode.title,
                    'overview': episode.overview,
                  },
                )
                .toList(),
          },
        )
        .toList(),
    'dubs': details.dubs
        .map(
          (dub) => {
            'subject_id': dub.subjectId,
            'language': dub.language,
            'label': dub.label,
          },
        )
        .toList(),
  };

  /// Restores a details object from the cache.
  static MediaDetails fromJson(
    Map<String, Object?> json,
    ProviderKind provider,
  ) {
    final seasons = <Season>[];
    for (final rawSeason in (json['seasons'] as List? ?? const [])) {
      if (rawSeason is! Map) continue;
      final map = rawSeason.cast<String, Object?>();
      final episodes = <Episode>[];
      for (final rawEpisode in (map['episodes'] as List? ?? const [])) {
        if (rawEpisode is! Map) continue;
        final episodeMap = rawEpisode.cast<String, Object?>();
        episodes.add(
          Episode(
            season: episodeMap['season'] as int? ?? 0,
            number: episodeMap['number'] as int? ?? 0,
            title: episodeMap['title'] as String?,
            overview: episodeMap['overview'] as String?,
          ),
        );
      }
      seasons.add(
        Season(number: map['number'] as int? ?? 1, episodes: episodes),
      );
    }

    final dubs = <AudioTrackOption>[];
    for (final rawDub in (json['dubs'] as List? ?? const [])) {
      if (rawDub is! Map) continue;
      final map = rawDub.cast<String, Object?>();
      dubs.add(
        AudioTrackOption(
          subjectId: map['subject_id'] as String? ?? '',
          language: map['language'] as String? ?? 'Unknown',
          label: map['label'] as String? ?? 'Unknown',
        ),
      );
    }

    return MediaDetails(
      id: ProviderMediaId(
        provider: provider,
        value: json['id'] as String? ?? '',
      ),
      title: json['title'] as String? ?? 'Unknown',
      mediaType: MediaType.fromWire(json['media_type'] as String?),
      year: json['year'] as String?,
      description: json['description'] as String?,
      tagline: json['tagline'] as String?,
      imdbRating: json['imdb_rating'] as String?,
      director: json['director'] as String?,
      stars: json['stars'] as String?,
      prints: json['prints'] as String?,
      audios: json['audios'] as String?,
      posterUrl: json['poster_url'] as String?,
      duration: json['duration'] as String?,
      genres: (json['genres'] as List? ?? const [])
          .map((entry) => entry.toString())
          .toList(),
      seasons: seasons,
      dubs: dubs,
    );
  }
}
