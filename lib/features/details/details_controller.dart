import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../../providers/content_provider.dart';
import '../../state/app_providers.dart';

/// The identity of a title inside a provider.
class DetailsArguments {
  const DetailsArguments({required this.provider, required this.id});

  final ProviderKind provider;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is DetailsArguments && other.provider == provider && other.id == id;

  @override
  int get hashCode => Object.hash(provider, id);
}

/// The query that identifies a set of releases.
class ReleaseQuery {
  const ReleaseQuery({
    required this.provider,
    required this.id,
    required this.season,
    required this.episode,
  });

  final ProviderKind provider;
  final String id;
  final int season;
  final int episode;

  @override
  bool operator ==(Object other) =>
      other is ReleaseQuery &&
      other.provider == provider &&
      other.id == id &&
      other.season == season &&
      other.episode == episode;

  @override
  int get hashCode => Object.hash(provider, id, season, episode);
}

/// The metadata of a title.
final detailsProvider = FutureProvider.family<MediaDetails, DetailsArguments>((
  ref,
  arguments,
) {
  final registry = ref.watch(providerRegistryProvider);
  final contentProvider = registry[arguments.provider];
  if (contentProvider == null) {
    throw ProviderUnavailable(
      'The provider ${arguments.provider.label} is not available.',
    );
  }
  final catalogService = ref.watch(catalogServiceProvider);
  return catalogService.details(
    provider: arguments.provider,
    id: arguments.id,
    loader: () => contentProvider.details(arguments.id),
  );
});

/// The playable releases of an episode.
final releasesProvider = FutureProvider.family<List<Release>, ReleaseQuery>((
  ref,
  query,
) async {
  final registry = ref.watch(providerRegistryProvider);
  final provider = registry[query.provider];
  if (provider is ReleaseProvider) {
    final releaseProvider = provider as ReleaseProvider;
    final releases = await releaseProvider.episodeStreams(
      query.id,
      query.season,
      query.episode,
    );
    if (releases.isEmpty) {
      throw const ProviderUnavailable('No stream sources available');
    }
    return releases;
  }
  throw ProviderUnavailable(
    'The provider ${query.provider.label} does not provide streams.',
  );
});

/// Raised when the requested provider cannot serve the request.
class ProviderUnavailable implements Exception {
  const ProviderUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
