// The constructors below use public named parameters that are assigned to
// private fields. Dart does not allow private named parameters, therefore the
// `prefer_initializing_formals` hint does not apply here.
// ignore_for_file: prefer_initializing_formals

import '../data/models/media.dart';
import '../data/models/provider_kind.dart';
import '../data/models/release.dart';
import '../providers/addons/addon_adapter.dart';
import '../providers/fourkhdhub/fourkhdhub_client.dart';
import '../providers/moviebox/moviebox_client.dart';

/// Resolves a release into a source the player can open.
///
/// Every provider needs a slightly different treatment, therefore the
/// resolution lives in one place instead of being spread over the UI.
class PlaybackService {
  PlaybackService({FourKHdHubClient? fourKHdHub, MovieBoxClient? movieBox})
    : _fourKHdHub = fourKHdHub,
      _movieBox = movieBox;

  final FourKHdHubClient? _fourKHdHub;
  final MovieBoxClient? _movieBox;

  /// Resolves the source of [release].
  ///
  /// The MovieBox links carry a time limited signature, therefore they are
  /// refreshed right before the playback starts.
  Future<PlaybackSource> resolve(
    Release release, {
    ResolutionIntent intent = ResolutionIntent.playback,
    String? subjectId,
  }) async {
    if (release.mirrors.isEmpty) {
      throw const PlaybackResolutionException('This release has no source.');
    }

    if (release.provider == ProviderKind.moviebox && subjectId != null) {
      final resourceId = release.resourceId;
      if (resourceId != null && resourceId.isNotEmpty) {
        final refreshed = await _movieBox?.refreshSource(subjectId, resourceId);
        if (refreshed != null) return refreshed;
      }
    }

    switch (release.provider) {
      case ProviderKind.fourkhdhub:
        final client = _fourKHdHub;
        if (client == null) {
          throw const PlaybackResolutionException(
            'The 4KHDHub provider is not available.',
          );
        }
        return client.resolveRelease(release, intent);

      case ProviderKind.addons:
        final source = AddonAdapter.releaseToPlaybackSource(release);
        if (source == null) {
          throw const PlaybackResolutionException(
            'This addon stream has no source.',
          );
        }
        return source;

      case ProviderKind.moviebox:
      case ProviderKind.dramachi:
      case ProviderKind.bdixCircleFtp:
      case ProviderKind.bdixDhakaFlix:
        final mirror = release.mirrors.first;
        return PlaybackSource(
          provider: release.provider,
          url: mirror.resolverUrl,
          headers: mirror.headers,
          sourceLabel: mirror.label.isEmpty
              ? release.sourceLabel
              : mirror.label,
        );
    }
  }

  /// Loads the external subtitles of a MovieBox resource.
  Future<List<SubtitleOption>> subtitles({
    required ProviderKind provider,
    required String subjectId,
    required String resourceId,
    required Future<Object?> Function() loader,
  }) async {
    if (provider != ProviderKind.moviebox) return const [];
    final payload = await loader();
    return MovieBoxSubtitles.parse(payload);
  }
}

/// Parses the MovieBox caption payloads.
abstract final class MovieBoxSubtitles {
  /// Converts a caption payload into selectable subtitle tracks.
  static List<SubtitleOption> parse(Object? payload) {
    final map = payload is Map ? payload.cast<String, Object?>() : null;
    if (map == null) return const [];
    final data = map['data'];
    final dataMap = data is Map ? data.cast<String, Object?>() : null;
    final raw = map['extCaptions'] ?? dataMap?['extCaptions'];
    if (raw is! List) return const [];

    final seen = <String>{};
    final options = <SubtitleOption>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final caption = entry.cast<String, Object?>();
      final url = caption['url'];
      if (url is! String || url.isEmpty) continue;
      if (url.contains('aa348f2541d13ffe')) continue;
      final sizeValue = caption['size'];
      final size = sizeValue is num
          ? sizeValue.toInt()
          : int.tryParse(sizeValue?.toString() ?? '') ?? 0;
      if (size > 0 && size <= 50) continue;
      final nameValue = caption['lanName'];
      final name = (nameValue is String && nameValue.trim().isNotEmpty)
          ? nameValue.trim()
          : (caption['lan']?.toString() ?? 'Unknown');
      if (name.toLowerCase() == 'in' && (size == 0 || size <= 100)) continue;
      if (!seen.add(url)) continue;
      options.add(SubtitleOption(name: name, url: url));
    }
    return options;
  }
}

/// Raised when a release cannot be turned into a playable source.
class PlaybackResolutionException implements Exception {
  const PlaybackResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}
