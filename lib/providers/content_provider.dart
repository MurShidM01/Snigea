import '../data/models/media.dart';
import '../data/models/provider_kind.dart';
import '../data/models/release.dart';

/// Optional capabilities of a provider.
class ProviderCapabilities {
  const ProviderCapabilities({
    this.supportsSearch = true,
    this.supportsPagination = false,
    this.supportsSeries = true,
    this.supportsSubtitles = true,
    this.supportsHomepage = false,
  });

  final bool supportsSearch;
  final bool supportsPagination;
  final bool supportsSeries;
  final bool supportsSubtitles;
  final bool supportsHomepage;
}

/// A provider that can be searched and inspected.
abstract interface class ContentProvider {
  /// Identity of the provider.
  ProviderKind get id;

  /// What the provider is able to do.
  ProviderCapabilities get capabilities;

  /// Searches the provider catalogue.
  Future<List<CatalogItem>> search(String query, {int page = 1});

  /// Loads the metadata of a single title.
  Future<MediaDetails> details(String id);
}

/// A provider that can resolve playable releases for an episode.
abstract interface class ReleaseProvider {
  /// Resolves the releases available for a given episode.
  Future<List<Release>> episodeStreams(String id, int season, int episode);
}
