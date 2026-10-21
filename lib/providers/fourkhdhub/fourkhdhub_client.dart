import 'package:dio/dio.dart';

import '../../core/logging/app_logger.dart';
import '../../core/network/http_client_factory.dart';
import '../../core/network/user_agents.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_error.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../content_provider.dart';
import 'fourkhdhub_parser.dart';
import 'hubcloud.dart';

/// The 4KHDHub client.
///
/// The provider is scraped from its public HTML pages; the resulting mirror
/// links are resolved and probed before playback so that expired or quota
/// limited mirrors are skipped.
class FourKHdHubClient implements ContentProvider, ReleaseProvider {
  FourKHdHubClient({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          HttpClientFactory.create(
            connectTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 20),
            userAgent: UserAgents.browser,
          ),
      _baseUrl = Uri.parse(baseUrl ?? defaultBaseUrl);

  /// The public site address.
  static const String defaultBaseUrl = 'https://4khdhub.one/';

  final Dio _dio;
  final Uri _baseUrl;

  String? _cachedPageKey;
  String? _cachedPage;
  DateTime? _cachedPageAt;

  @override
  ProviderKind get id => ProviderKind.fourkhdhub;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsPagination: false,
    supportsSeries: true,
    supportsSubtitles: false,
    supportsHomepage: false,
  );

  /// Performs a health check against the provider.
  Future<void> healthCheck() async {
    final response = await _dio.get<String>(
      _baseUrl.toString(),
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ProviderUnavailableError('HTTP status $status');
    }
  }

  /// The latest releases of the start page.
  ///
  /// The start page lists the most recent uploads with the same card markup
  /// as the search results, therefore the same parser is used.
  Future<List<CatalogItem>> latest() async {
    final html = await _fetchText(_baseUrl);
    return FourKHdHubParser.parseSearch(_baseUrl.toString(), html);
  }

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async {
    final url = _baseUrl.replace(
      queryParameters: {..._baseUrl.queryParameters, 's': query},
    );
    final html = await _fetchText(url);
    return FourKHdHubParser.parseSearch(_baseUrl.toString(), html);
  }

  @override
  Future<MediaDetails> details(String id) async {
    final html = await _fetchCachedPage(id);
    try {
      return FourKHdHubParser.parseDetails(id, html);
    } on FourKHdHubParseException catch (error) {
      throw ParsingError(error.message);
    }
  }

  @override
  Future<List<Release>> episodeStreams(
    String id,
    int season,
    int episode,
  ) async {
    final html = await _fetchCachedPage(id);
    final releases = FourKHdHubParser.parseReleases(
      html,
      season: season,
      episode: episode,
    );
    if (releases.isEmpty) {
      throw const ProviderUnavailableError('No exact release found');
    }
    return releases;
  }

  /// Resolves a release into a playable source.
  ///
  /// Every mirror is resolved, probed with a range request and scored; the
  /// first seekable candidate wins, otherwise the best fallback is used.
  Future<PlaybackSource> resolveRelease(
    Release release,
    ResolutionIntent intent,
  ) async {
    if (release.provider != ProviderKind.fourkhdhub) {
      throw const ParsingError('release belongs to another provider');
    }
    if (release.mirrors.isEmpty) {
      throw const ProviderUnavailableError('no working mirror links extracted');
    }

    final referer = _baseUrl.toString().replaceAll(RegExp(r'/$'), '');
    final fallbacks = <_PreflightResult>[];
    var spawned = 0;

    for (final mirror in release.mirrors) {
      if (spawned >= 6) break;
      spawned++;
      final candidates = await _resolveMirror(mirror.resolverUrl, intent);
      for (final candidate in candidates) {
        final headers = <MapEntry<String, String>>[
          ...candidate.headers,
          if (!candidate.headers.any((h) => h.key.toLowerCase() == 'referer'))
            MapEntry('Referer', referer),
          if (!candidate.headers.any(
            (h) => h.key.toLowerCase() == 'user-agent',
          ))
            const MapEntry('User-Agent', UserAgents.browser),
        ];
        try {
          final probe = await _preflight(candidate.url, headers);
          if (probe.isSeekable) {
            return PlaybackSource(
              provider: ProviderKind.fourkhdhub,
              url: probe.url,
              headers: headers,
              sourceLabel: candidate.label,
            );
          }
          fallbacks.add(
            _PreflightResult(
              probe.url,
              candidate.label,
              headers,
              isSeekable: false,
            ),
          );
        } on MirrorResolutionException {
          continue;
        }
      }
    }

    if (fallbacks.isEmpty) {
      throw const ProviderUnavailableError('all candidate mirrors failed');
    }
    final best = fallbacks.first;
    return PlaybackSource(
      provider: ProviderKind.fourkhdhub,
      url: best.url,
      headers: best.headers,
      sourceLabel: best.label,
    );
  }

  Future<List<MirrorCandidate>> _resolveMirror(
    String url,
    ResolutionIntent intent,
  ) async {
    try {
      if (url.contains('hubcloud.')) {
        return await HubCloud.resolve(_dio, url, intent);
      }
      if (url.contains('hubdrive.')) {
        return await HubCloud.resolveHubDrive(_dio, url, intent);
      }
      if (url.contains('greenmotors.') || url.contains('greenmountmotors.')) {
        return await HubCloud.resolveGreenMotors(_dio, url, intent);
      }
      final valid = HubCloud.validatePlaybackUrl(url);
      if (valid == null) return const [];
      return [MirrorCandidate(valid, 'Source')];
    } on MirrorResolutionException catch (error) {
      AppLogger.warn('4KHDHub mirror resolution failed: ${error.message}');
      return const [];
    }
  }

  /// Probes a candidate URL with a range request.
  Future<_PreflightResult> _preflight(
    String url,
    List<MapEntry<String, String>> headers,
  ) async {
    final valid = HubCloud.validatePlaybackUrl(url);
    if (valid == null) {
      throw const MirrorResolutionException('invalid playback url');
    }

    final response = await _dio.get<ResponseBody>(
      valid,
      options: Options(
        headers: {
          for (final header in headers) header.key: header.value,
          'Range': 'bytes=0-8191',
        },
        responseType: ResponseType.stream,
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw MirrorResolutionException('HTTP status $status');
    }

    var isSeekable = status == 206;
    var finalUrl = response.realUri;
    final contentType = (response.headers.value('content-type') ?? '')
        .toLowerCase();

    if (_isTextual(contentType)) {
      final body = await _readTextBody(response);
      if (_looksLikeExpired(body)) {
        throw const MirrorResolutionException(
          'upstream mirror reported expired file link',
        );
      }
      final wrapped = finalUrl.queryParameters['link'];
      if (wrapped == null || !wrapped.startsWith('https://')) {
        throw MirrorResolutionException(
          'invalid media content type: $contentType',
        );
      }
      final wrappedValid = HubCloud.validatePlaybackUrl(wrapped);
      if (wrappedValid == null) {
        throw const MirrorResolutionException('invalid wrapped media url');
      }
      final wrappedResponse = await _dio.get<ResponseBody>(
        wrappedValid,
        options: Options(
          headers: {
            for (final header in headers) header.key: header.value,
            'Range': 'bytes=0-8191',
          },
          responseType: ResponseType.stream,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final wrappedStatus = wrappedResponse.statusCode ?? 0;
      if (wrappedStatus < 200 || wrappedStatus >= 300) {
        throw MirrorResolutionException('HTTP status $wrappedStatus');
      }
      isSeekable = wrappedStatus == 206;
      finalUrl = wrappedResponse.realUri;
      final wrappedType = (wrappedResponse.headers.value('content-type') ?? '')
          .toLowerCase();
      if (_isTextual(wrappedType)) {
        final wrappedBody = await _readTextBody(wrappedResponse);
        if (_looksLikeExpired(wrappedBody)) {
          throw const MirrorResolutionException(
            'upstream mirror reported expired file link',
          );
        }
        throw MirrorResolutionException(
          'invalid wrapped media content type: $wrappedType',
        );
      }
    }

    return _PreflightResult(
      finalUrl.toString(),
      '',
      headers,
      isSeekable: isSeekable,
    );
  }

  static bool _isTextual(String contentType) =>
      contentType.contains('text/html') ||
      contentType.contains('application/zip') ||
      contentType.contains('text/plain');

  static bool _looksLikeExpired(String body) {
    final lower = body.toLowerCase();
    for (final marker in const [
      'failed to extract link',
      'token expired',
      'file not found',
      '404 not found',
      'link has expired',
      'expired',
      'access denied',
      'downloadquotaexceeded',
      'generate link again',
    ]) {
      if (lower.contains(marker)) return true;
    }
    return false;
  }

  static Future<String> _readTextBody(Response<ResponseBody> response) async {
    final buffer = StringBuffer();
    await for (final chunk in response.data!.stream) {
      buffer.write(String.fromCharCodes(chunk));
      if (buffer.length > 8192) break;
    }
    return buffer.toString();
  }

  Future<String> _fetchCachedPage(String id) async {
    final url = _providerUrl(id);
    final key = url.toString();
    final cachedAt = _cachedPageAt;
    if (_cachedPageKey == key &&
        _cachedPage != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(seconds: 60)) {
      return _cachedPage!;
    }
    final html = await _fetchText(url);
    _cachedPageKey = key;
    _cachedPage = html;
    _cachedPageAt = DateTime.now();
    return html;
  }

  Uri _providerUrl(String id) {
    final resolved = _baseUrl.resolve(id.replaceFirst(RegExp(r'^/+'), ''));
    if (resolved.host != _baseUrl.host) {
      throw const ProviderUnavailableError('Invalid 4KHDHub URL');
    }
    return resolved;
  }

  Future<String> _fetchText(Uri url) async {
    final response = await _dio.get<String>(
      url.toString(),
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ProviderUnavailableError('HTTP status $status');
    }
    return response.data ?? '';
  }
}

class _PreflightResult {
  const _PreflightResult(
    this.url,
    this.label,
    this.headers, {
    required this.isSeekable,
  });

  final String url;
  final String label;
  final List<MapEntry<String, String>> headers;
  final bool isSeekable;
}
