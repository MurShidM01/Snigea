import 'dart:async';

import '../../core/json/json_utils.dart';
import '../../core/logging/app_logger.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_error.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../content_provider.dart';
import 'addon_adapter.dart';
import 'addon_client.dart';
import 'addon_models.dart';

/// The result of aggregating the streams of several addons.
class AggregatedStreams {
  const AggregatedStreams(this.releases, this.blockedAddons);

  final List<Release> releases;

  /// Addons that only offered torrent / non HTTP streams.
  final List<String> blockedAddons;
}

/// Aggregates the streams offered by the installed addons.
abstract final class AddonAggregator {
  /// Queries every stream capable addon and merges the results.
  static Future<AggregatedStreams> aggregateStreams({
    required AddonClient client,
    required List<InstalledAddon> addons,
    required String subjectId,
    required int season,
    required int episode,
    required bool isSeries,
  }) async {
    final streamAddons = addons
        .where((addon) => addon.enabled && addon.providesStream)
        .toList();
    if (streamAddons.isEmpty) {
      return const AggregatedStreams([], []);
    }

    final cleanId = subjectId.split(':').last;
    final mediaType = isSeries ? 'series' : 'movie';
    final streamId = (isSeries && episode > 0)
        ? '$cleanId:$season:$episode'
        : cleanId;

    final results = await Future.wait(
      streamAddons.map((addon) async {
        final baseUrl = AddonClient.baseAddonUrl(addon.manifestUrl);
        try {
          final items = await client
              .fetchStreams(baseUrl, mediaType, streamId)
              .timeout(const Duration(seconds: 5));
          final releases = <Release>[];
          for (final item in items) {
            final release = AddonAdapter.streamItemToRelease(
              addon.name,
              item,
              season: season,
              episode: episode,
            );
            if (release != null) releases.add(release);
          }
          if (items.isNotEmpty && releases.isEmpty) {
            return (releases, addon.name);
          }
          return (releases, null);
        } on TimeoutException {
          AppLogger.warn('addon ${addon.name} timed out fetching streams');
          return (<Release>[], null);
        } on AddonException catch (error) {
          AppLogger.warn('addon ${addon.name} failed: ${error.message}');
          return (<Release>[], null);
        }
      }),
    );

    final allReleases = <Release>[];
    final blocked = <String>[];
    for (final result in results) {
      allReleases.addAll(result.$1);
      if (result.$2 != null) blocked.add(result.$2!);
    }

    final deduplicated = <Release>[];
    for (final release in allReleases) {
      final direct = release.directUrl ?? '';
      if (direct.isEmpty) {
        deduplicated.add(release);
        continue;
      }
      final existingIndex = deduplicated.indexWhere(
        (entry) => entry.directUrl == direct,
      );
      if (existingIndex < 0) {
        deduplicated.add(release);
        continue;
      }
      final existing = deduplicated[existingIndex];
      final mirrors = [...existing.mirrors];
      for (final mirror in release.mirrors) {
        final known = mirrors.any(
          (m) => m.resolverUrl == mirror.resolverUrl && m.label == mirror.label,
        );
        if (!known) mirrors.add(mirror);
      }
      deduplicated[existingIndex] = existing.copyWith(mirrors: mirrors);
    }

    deduplicated.sort((a, b) {
      final byQuality = _qualityScore(b.quality)
          .compareTo(_qualityScore(a.quality));
      if (byQuality != 0) return byQuality;
      final bySize = (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
      if (bySize != 0) return bySize;
      return a.sourceLabel.compareTo(b.sourceLabel);
    });

    return AggregatedStreams(deduplicated, blocked);
  }

  static int _qualityScore(String? quality) {
    switch (quality) {
      case '2160p':
        return 40;
      case '1080p':
        return 30;
      case '720p':
        return 20;
      case '480p':
        return 10;
      default:
        return 0;
    }
  }
}

/// The Stremio addon provider.
///
/// Addons are user supplied, therefore the provider resolves its addon list
/// through a callback so that settings changes are picked up immediately.
class AddonProvider implements ContentProvider, ReleaseProvider {
  AddonProvider({required this._client, required this._addons});
  final AddonClient _client;
  final List<InstalledAddon> Function() _addons;

  @override
  ProviderKind get id => ProviderKind.addons;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsPagination: false,
    supportsSeries: true,
    supportsSubtitles: false,
    supportsHomepage: false,
  );

  /// The addons that are currently enabled.
  List<InstalledAddon> get enabledAddons =>
      _addons().where((addon) => addon.enabled).toList();

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async {
    final candidates = enabledAddons
        .where((addon) => addon.providesMeta || addon.providesCatalog)
        .toList();
    if (candidates.isEmpty) return const [];

    for (final addon in candidates) {
      final baseUrl = AddonClient.baseAddonUrl(addon.manifestUrl);
      final results = await Future.wait([
        _safeSearch(baseUrl, 'movie', query),
        _safeSearch(baseUrl, 'series', query),
      ]);

      final combined = <CatalogItem>[];
      final seen = <String>{};
      for (final group in results) {
        for (final item in group) {
          final catalogItem = AddonAdapter.metaToCatalogItem(item);
          if (!seen.add(catalogItem.id.value)) continue;
          combined.add(catalogItem);
        }
      }
      if (combined.isNotEmpty) return combined;
    }
    return const [];
  }

  Future<List<MetaItem>> _safeSearch(
    String baseUrl,
    String type,
    String query,
  ) async {
    try {
      return await _client.fetchCatalogSearch(baseUrl, type, 'top', query);
    } on AddonException {
      return const [];
    }
  }

  @override
  Future<MediaDetails> details(String id) async {
    final separator = id.indexOf(':');
    final hint = separator > 0 ? id.substring(0, separator) : null;
    final cleanId = separator > 0 ? id.substring(separator + 1) : id;

    final typeHint =
        (hint != null &&
            const {'movie', 'series', 'tv', 'anime', 'other'}.contains(hint))
        ? hint
        : null;

    final probeOrder = <String>[
      ?typeHint,
      'series',
      'movie',
      'tv',
      'anime',
      'other',
    ];

    final candidates = enabledAddons.toList()
      ..sort((a, b) {
        final aMeta = a.providesMeta ? 0 : 1;
        final bMeta = b.providesMeta ? 0 : 1;
        return aMeta.compareTo(bMeta);
      });

    MetaDetail? best;
    for (final addon in candidates) {
      final baseUrl = AddonClient.baseAddonUrl(addon.manifestUrl);
      for (final type in probeOrder) {
        try {
          final detail = await _client.fetchMeta(baseUrl, type, cleanId);
          if (detail.id != cleanId) continue;
          if (detail.name.trim().isEmpty && (detail.title ?? '').isEmpty) {
            continue;
          }
          if (detail.videos.isNotEmpty || type == 'series' || type == 'tv') {
            return AddonAdapter.metaDetailToMediaDetails(detail);
          }
          if (type == 'movie' && typeHint == 'movie') {
            return AddonAdapter.metaDetailToMediaDetails(detail);
          }
          best ??= detail;
        } on AddonException {
          continue;
        }
      }
    }

    if (best != null) return AddonAdapter.metaDetailToMediaDetails(best);
    throw const NotFoundError();
  }

  @override
  Future<List<Release>> episodeStreams(
    String id,
    int season,
    int episode,
  ) async {
    final aggregated = await AddonAggregator.aggregateStreams(
      client: _client,
      addons: _addons(),
      subjectId: id,
      season: season,
      episode: episode,
      isSeries: season > 0 || episode > 0,
    );
    if (aggregated.releases.isEmpty) {
      throw const ProviderUnavailableError('No stream sources available');
    }
    return aggregated.releases;
  }

  /// Loads a catalogue of an addon, used by the browse screen.
  Future<List<CatalogItem>> catalog({
    required String manifestUrl,
    required String type,
    required String catalogId,
    String? extra,
  }) async {
    final baseUrl = AddonClient.baseAddonUrl(manifestUrl);
    final items = await _client.fetchCatalog(
      baseUrl,
      type,
      catalogId,
      extra: extra,
    );
    return items.map(AddonAdapter.metaToCatalogItem).toList();
  }

  /// The catalogues that can be browsed with the installed addons.
  static List<
    ({String label, String manifestUrl, String type, String catalogId})
  >
  curatedCatalogs(List<InstalledAddon> addons) {
    final enabled = addons
        .where((a) => a.enabled && a.providesCatalog)
        .toList();
    final targets =
        <({String label, String manifestUrl, String type, String catalogId})>[];

    for (final addon in enabled) {
      final suffix = enabled.length > 1 ? ' (${addon.name})' : '';
      final hasMovies =
          addon.types.isEmpty ||
          addon.types.any((t) => t.toLowerCase() == 'movie');
      final hasSeries =
          addon.types.isEmpty ||
          addon.types.any((t) => t.toLowerCase() == 'series');

      if (hasMovies) {
        targets.add((
          label: 'Top Movies$suffix',
          manifestUrl: addon.manifestUrl,
          type: 'movie',
          catalogId: 'top',
        ));
      }
      if (hasSeries) {
        targets.add((
          label: 'Top Series$suffix',
          manifestUrl: addon.manifestUrl,
          type: 'series',
          catalogId: 'top',
        ));
      }
      if (hasMovies && addon.isCore) {
        targets.add((
          label: 'Top Rated Movies$suffix',
          manifestUrl: addon.manifestUrl,
          type: 'movie',
          catalogId: 'imdbRating',
        ));
      }
      if (hasSeries && addon.isCore) {
        targets.add((
          label: 'Top Rated Series$suffix',
          manifestUrl: addon.manifestUrl,
          type: 'series',
          catalogId: 'imdbRating',
        ));
      }
      if (targets.length >= 6) break;
    }

    if (targets.isEmpty) {
      final cinemeta = InstalledAddon.cinemetaDefault();
      targets.addAll([
        (
          label: 'Top Movies',
          manifestUrl: cinemeta.manifestUrl,
          type: 'movie',
          catalogId: 'top',
        ),
        (
          label: 'Top Series',
          manifestUrl: cinemeta.manifestUrl,
          type: 'series',
          catalogId: 'top',
        ),
        (
          label: 'Top Rated Movies',
          manifestUrl: cinemeta.manifestUrl,
          type: 'movie',
          catalogId: 'imdbRating',
        ),
        (
          label: 'Top Rated Series',
          manifestUrl: cinemeta.manifestUrl,
          type: 'series',
          catalogId: 'imdbRating',
        ),
      ]);
    }
    return targets.take(6).toList();
  }
}

/// Parses the `metas` array of an addon catalogue response.
List<MetaItem> parseMetas(Object? raw) {
  final map = asMap(raw);
  final list = asList(map?['metas']) ?? asList(raw) ?? const [];
  return list
      .map(asMap)
      .whereType<Map<String, Object?>>()
      .map(MetaItem.fromJson)
      .toList();
}
