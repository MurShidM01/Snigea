import 'provider_kind.dart';

/// One playable mirror of a release.
class SourceMirror {
  const SourceMirror({
    required this.label,
    required this.resolverUrl,
    this.headers = const [],
    this.directFile = false,
  });

  final String label;
  final String resolverUrl;
  final List<MapEntry<String, String>> headers;
  final bool directFile;
}

/// A downloadable / playable release reported by a provider.
class Release {
  const Release({
    required this.provider,
    required this.filename,
    this.quality,
    this.codec,
    this.language,
    this.sizeBytes,
    this.season,
    this.episode,
    this.mirrors = const [],
    this.resourceId,
  });

  final ProviderKind provider;
  final String filename;
  final String? quality;
  final String? codec;
  final String? language;
  final int? sizeBytes;
  final int? season;
  final int? episode;
  final List<SourceMirror> mirrors;
  final String? resourceId;

  /// True when the release advertises multiple renditions.
  bool get isMultiResolution {
    final q = quality?.toLowerCase();
    return q == 'multi' || q == 'multi-res';
  }

  /// Vertical resolution in pixels, defaulting to 1080 like the reference.
  int get resolutionU64 {
    final q = quality?.trim();
    if (q == null) return 1080;
    if (q.toLowerCase() == '4k' || q.toLowerCase() == 'uhd') return 2160;
    final stripped = q.replaceAll(RegExp(r'[pP]$'), '');
    final parsed = int.tryParse(stripped);
    return parsed ?? 1080;
  }

  /// Resolution used for sorting; `-1` marks multi-resolution releases.
  int get resolutionI64 => isMultiResolution ? -1 : resolutionU64;

  /// Label of the first mirror, or a provider specific default.
  String get sourceLabel {
    if (mirrors.isNotEmpty) return mirrors.first.label;
    switch (provider) {
      case ProviderKind.fourkhdhub:
        return '4KHDHub';
      case ProviderKind.bdixCircleFtp:
        return 'CircleFTP';
      case ProviderKind.bdixDhakaFlix:
        return 'DhakaFlix';
      case ProviderKind.addons:
        return 'Addon';
      case ProviderKind.dramachi:
        return 'Dramachi';
      case ProviderKind.moviebox:
        return 'Direct';
    }
  }

  /// The primary URL of this release, if any.
  String? get directUrl => mirrors.isEmpty ? null : mirrors.first.resolverUrl;

  Release copyWith({List<SourceMirror>? mirrors}) => Release(
    provider: provider,
    filename: filename,
    quality: quality,
    codec: codec,
    language: language,
    sizeBytes: sizeBytes,
    season: season,
    episode: episode,
    mirrors: mirrors ?? this.mirrors,
    resourceId: resourceId,
  );
}

/// A fully resolved source that can be handed to the player.
class PlaybackSource {
  const PlaybackSource({
    required this.provider,
    required this.url,
    this.headers = const [],
    this.subtitle,
    this.sourceLabel = '',
    this.maxHeight,
  });

  final ProviderKind provider;
  final String url;
  final List<MapEntry<String, String>> headers;
  final String? subtitle;
  final String sourceLabel;
  final int? maxHeight;
}

/// Whether a source is being resolved for playback or for download.
enum ResolutionIntent { playback, download }
