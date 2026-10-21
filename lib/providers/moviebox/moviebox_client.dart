import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/json/json_utils.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/http_client_factory.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_error.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../content_provider.dart';
import 'moviebox_crypto.dart';
import 'moviebox_parser.dart';
import 'moviebox_session.dart';

/// Persists MovieBox sessions between app restarts.
abstract interface class MovieBoxSessionStore {
  /// Loads a previously stored session, if any.
  Future<MovieBoxSession?> load();

  /// Stores a session for later reuse.
  Future<void> save(MovieBoxSession session);

  /// Removes the stored session.
  Future<void> clear();
}

/// A [MovieBoxSessionStore] that keeps everything in memory.
class InMemoryMovieBoxSessionStore implements MovieBoxSessionStore {
  MovieBoxSession? _session;

  @override
  Future<MovieBoxSession?> load() async => _session;

  @override
  Future<void> save(MovieBoxSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

/// The MovieBox BFF client.
///
/// Requests are signed exactly like the upstream mobile client does; the
/// host pool is rotated on failures so a single unreachable edge node does
/// not break the app.
class MovieBoxClient implements ContentProvider, ReleaseProvider {
  MovieBoxClient({Dio? dio, MovieBoxSessionStore? sessionStore})
    : _dio =
          dio ??
          HttpClientFactory.create(
            connectTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 15),
          ),
      _sessionStore = sessionStore ?? InMemoryMovieBoxSessionStore() {
    final identity = MovieBoxCrypto.generateClientInfoAndUa();
    _userAgent = identity.userAgent;
    _clientInfo = identity.clientInfo;
    _spoofedIp = MovieBoxCrypto.randomSpoofedIp();
  }

  /// The pool of API hosts, rotated on failure.
  static const List<String> hostPool = [
    'https://api6.aoneroom.com',
    'https://api5.aoneroom.com',
    'https://api4.aoneroom.com',
    'https://api4sg.aoneroom.com',
    'https://api3.aoneroom.com',
    'https://api6sg.aoneroom.com',
    'https://api.inmoviebox.com',
  ];

  /// Statuses that should be retried on the next host.
  static const List<int> retryStatusCodes = [
    403,
    406,
    407,
    429,
    500,
    502,
    503,
    504,
  ];

  final Dio _dio;
  final MovieBoxSessionStore _sessionStore;

  late final String _userAgent;
  late final String _clientInfo;
  late final String _spoofedIp;

  MovieBoxSession? _session;
  int _activeBaseIndex = 0;
  Future<String>? _sessionFuture;

  /// The user agent used for stream requests.
  String get userAgent => _userAgent;

  /// The client identity that is signed into the requests.
  String get clientInfo => _clientInfo;

  /// The address that is signed into the requests.
  String get spoofedIp => _spoofedIp;

  @override
  ProviderKind get id => ProviderKind.moviebox;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsPagination: true,
    supportsSeries: true,
    supportsSubtitles: true,
    supportsHomepage: true,
  );

  // ---------------------------------------------------------------- session

  /// Returns a valid session token, creating one when necessary.
  Future<String> ensureSession() {
    final pending = _sessionFuture;
    if (pending != null) return pending;
    final future = _ensureSessionInternal();
    _sessionFuture = future;
    return future.whenComplete(() {
      if (identical(_sessionFuture, future)) _sessionFuture = null;
    });
  }

  Future<String> _ensureSessionInternal() async {
    final current = _session;
    if (current != null && current.isValid()) return current.token;

    final persisted = await _sessionStore.load();
    if (persisted != null && persisted.isValid()) {
      _session = persisted;
      return persisted.token;
    }

    final session = await _fetchFreshSession();
    _session = session;
    await _sessionStore.save(session);
    return session.token;
  }

  Future<MovieBoxSession> _fetchFreshSession() async {
    const path = '/wefeed-mobile-bff/user-api/visitor-login';
    final value = await _requestHosts(
      'POST',
      path,
      body: '{}',
      authToken: null,
    );
    final map = asMap(value);
    final token = asString(map?['token']);
    if (token == null || token.trim().isEmpty) {
      throw ProviderUnavailableError('Missing token');
    }
    final uid = asString(pick(map, ['uid', 'userId']));
    return MovieBoxSession.fromTokenAndPayload(token, explicitUserId: uid);
  }

  /// Drops the current session so the next request creates a fresh one.
  Future<void> invalidateSession() async {
    _session = null;
    await _sessionStore.clear();
  }

  void _absorbXUser(Headers headers) {
    final raw = headers.value('x-user');
    if (raw == null || raw.isEmpty) return;
    try {
      final json = jsonDecode(raw);
      final map = asMap(json);
      final token = asString(map?['token']);
      if (token == null || token.isEmpty) return;
      final uid = asString(pick(map, ['uid', 'userId']));
      final session = MovieBoxSession.fromTokenAndPayload(
        token,
        explicitUserId: uid,
      );
      _session = session;
      unawaited(_sessionStore.save(session));
    } on FormatException {
      // The header is optional; ignore malformed values.
    }
  }

  // --------------------------------------------------------------- requests

  /// Performs a signed GET request and returns the `data` node.
  Future<Object?> get(String pathAndQuery) => _request('GET', pathAndQuery);

  /// Performs a signed POST request and returns the `data` node.
  Future<Object?> post(String pathAndQuery, Object body) =>
      _request('POST', pathAndQuery, body: jsonEncode(body));

  Future<Object?> _request(
    String method,
    String pathAndQuery, {
    Object? body,
  }) async {
    final token = await ensureSession();
    try {
      return await _requestHosts(
        method,
        pathAndQuery,
        body: body as String?,
        authToken: token,
      );
    } on ProviderError {
      await invalidateSession();
      final freshToken = await ensureSession();
      return _requestHosts(
        method,
        pathAndQuery,
        body: body as String?,
        authToken: freshToken,
      );
    }
  }

  Future<Object?> _requestHosts(
    String method,
    String pathAndQuery, {
    String? body,
    String? authToken,
  }) async {
    final startIndex = _activeBaseIndex;
    var backoff = const Duration(milliseconds: 50);

    for (var i = 0; i < hostPool.length; i++) {
      if (i > 0) {
        await Future<void>.delayed(backoff);
        backoff = const Duration(milliseconds: 50);
      }
      final index = (startIndex + i) % hostPool.length;
      final base = hostPool[index];
      final url = '$base$pathAndQuery';

      final headers = MovieBoxCrypto.buildSignedHeaders(
        method: method,
        url: url,
        body: body,
        authToken: authToken,
        userAgent: _userAgent,
        clientInfo: _clientInfo,
        spoofedIp: _spoofedIp,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );

      try {
        final response = await _dio.request<Object?>(
          url,
          data: body,
          options: Options(
            method: method,
            headers: headers,
            responseType: ResponseType.json,
            validateStatus: (status) => status != null && status < 600,
          ),
        );

        _absorbXUser(response.headers);
        final status = response.statusCode ?? 0;

        if (retryStatusCodes.contains(status)) {
          AppLogger.warn(
            'moviebox host $index returned retryable status $status '
            '[${AppLogger.sanitizeUrl(url)}]',
          );
          _activeBaseIndex = (index + 1) % hostPool.length;
          if (status == 429) {
            final retryAfter = response.headers.value('retry-after');
            final seconds = retryAfter == null
                ? null
                : int.tryParse(retryAfter);
            backoff = Duration(
              milliseconds: ((seconds ?? 0) * 1000).clamp(100, 3000),
            );
          }
          continue;
        }

        _activeBaseIndex = index;
        return _parseResponse(response);
      } on DioException catch (error) {
        AppLogger.warn(
          'moviebox host $index request failed: ${error.type} '
          '[${AppLogger.sanitizeUrl(url)}]',
        );
        _activeBaseIndex = (index + 1) % hostPool.length;
      }
    }

    AppLogger.error('moviebox: all hosts exhausted');
    throw const ProviderUnavailableError('All hosts exhausted');
  }

  Object? _parseResponse(Response<Object?> response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      if (status == 429) throw const RateLimitedError();
      if (status == 404) throw const NotFoundError();
      if (status == 406) {
        // The upstream answers with "no content" when the visitor session is
        // not allowed to use the catalogue endpoints.
        throw const ProviderUnavailableError(
          'MovieBox does not return any content for a visitor session right '
          'now. The homepage catalogue still works, or try another provider.',
        );
      }
      throw ProviderUnavailableError('HTTP status $status');
    }

    Object? body = response.data;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException catch (error) {
        throw ParsingError(error.message);
      }
    }
    if (body == null) return null;

    final map = asMap(body);
    if (map != null && map.containsKey('data')) {
      return map['data'];
    }
    return body;
  }

  // -------------------------------------------------------------- endpoints

  /// Searches the catalogue.
  Future<Object?> searchPayload(String query, int page) => post(
    '/wefeed-mobile-bff/subject-api/search/v2',
    {'keyword': query, 'page': page, 'perPage': 15, 'subjectType': 0},
  );

  /// Loads the `play-info` payload of an episode.
  Future<Object?> playInfo(String subjectId, int season, int episode) {
    final path = (season == 0 && episode == 0)
        ? '/wefeed-mobile-bff/subject-api/play-info/v2?subjectId=$subjectId'
        : '/wefeed-mobile-bff/subject-api/play-info/v2'
              '?subjectId=$subjectId&se=$season&ep=$episode';
    return get(path);
  }

  /// Loads the `resource` list of an episode.
  Future<Object?> resources(
    String subjectId,
    int season,
    int episode,
    int page,
    String? resolution,
    int perPage,
  ) {
    final resolutionParam = (resolution == null || resolution.isEmpty)
        ? ''
        : '&resolution=$resolution';
    final path = (season == 0 && episode == 0)
        ? '/wefeed-mobile-bff/subject-api/resource'
              '?subjectId=$subjectId&page=$page&perPage=$perPage$resolutionParam'
        : '/wefeed-mobile-bff/subject-api/resource'
              '?subjectId=$subjectId&se=$season&ep=$episode&page=$page'
              '&perPage=$perPage$resolutionParam';
    return get(path);
  }

  /// Loads the metadata of a subject, including the season index for series.
  Future<Object?> detailsPayload(String subjectId) async {
    final details = await get(
      '/wefeed-mobile-bff/subject-api/get?subjectId=$subjectId',
    );
    final map = asMap(details);
    final stype = asInt(pick(map, ['subjectType', 'stype'])) ?? 1;
    if (stype == 2) {
      try {
        final seasonInfo = await get(
          '/wefeed-mobile-bff/subject-api/season-info?subjectId=$subjectId',
        );
        if (map != null) {
          map['seasons'] = seasonInfo;
        }
      } on ProviderError {
        // Seasons are optional; keep the rest of the metadata.
      }
    }
    return details;
  }

  /// Loads a homepage tab.
  Future<Object?> homepage(String tabId, int page) =>
      get('/wefeed-mobile-bff/tab-operating?page=$page&tabId=$tabId&version=');

  /// The path of the resource failover API.
  static String resourcePositionPath(
    String subjectId,
    String resourceId,
    String failedUrl,
  ) {
    final query = Uri(
      queryParameters: {
        'subjectId': subjectId,
        'resourceId': resourceId,
        'failUrl': failedUrl,
        'failCode': '404',
        'resourceNum': '0',
        'isVip': 'true',
      },
    ).query;
    return '/wefeed-mobile-bff/subject-api/resource-position/v2?$query';
  }

  /// The path of the episode resource listing.
  static String episodeResourcePath(String subjectId, int season, int episode) {
    return '/wefeed-mobile-bff/subject-api/resource/v2?subjectId=$subjectId'
        '&page=1&perPage=20&all=0&startPosition=1&endPosition=1&pagerMode=2'
        '&resolution=0&se=$season&epFrom=$episode&epTo=$episode&isVip=true';
  }

  /// Loads the external captions of a resource.
  Future<Object?> extCaptions(String subjectId, String resourceId) => get(
    '/wefeed-mobile-bff/subject-api/get-ext-captions'
    '?subjectId=$subjectId&resourceId=$resourceId',
  );

  /// The resolutions that are available for a subject.
  Future<List<int>> collectionResolutions(String subjectId) async {
    final payload = await resources(subjectId, 0, 0, 1, null, 20);
    final map = asMap(payload);
    final resolutions = <int>{};

    for (final entry in asList(map?['collectionResolutions']) ?? const []) {
      final value = asInt(asMap(entry)?['resolution']);
      if (value != null && value > 0) resolutions.add(value);
    }
    if (resolutions.isEmpty) {
      for (final entry in asList(map?['list']) ?? const []) {
        final value = asInt(asMap(entry)?['resolution']);
        if (value != null && value > 0) resolutions.add(value);
      }
    }
    if (resolutions.isEmpty) {
      return const [1080, 720, 480, 360];
    }
    final sorted = resolutions.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  // ------------------------------------------------------- provider methods

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async {
    final payload = await searchPayload(query, page);
    return MovieBoxParser.searchJsonToCatalog(payload);
  }

  @override
  Future<MediaDetails> details(String id) async {
    final payload = await detailsPayload(id);
    return MovieBoxParser.detailsJsonToMediaDetails(payload);
  }

  /// The releases of the `resourceDetectors` block of the details payload.
  Future<List<Release>> _detectorReleases(
    String id,
    int season,
    int episode,
  ) async {
    try {
      final payload = await detailsPayload(id);
      return MovieBoxParser.detectorJsonToReleases(
        payload,
        season: season,
        episode: episode,
        userAgent: _userAgent,
      );
    } catch (error) {
      AppLogger.warn('moviebox detector lookup failed: $error');
      return const [];
    }
  }

  /// The resource listing of a single episode.
  ///
  /// The legacy `resource` listing ignores `se`/`ep` and paginates the whole
  /// series, therefore the `resource/v2` endpoint is used instead.
  Future<Object?> _episodeResources(String id, int season, int episode) {
    return get(episodeResourcePath(id, season, episode));
  }

  /// Replaces the placeholder clips of a resource listing with the original
  /// files.
  Future<List<Release>> _recoverTrailers(
    Object? payload, {
    required int season,
    required int episode,
    required String id,
  }) async {
    final recovered = <Release>[];
    for (final item in MovieBoxParser.resourceItems(payload)) {
      final release = MovieBoxParser.resourceItemToRelease(item);
      if (release.mirrors.isNotEmpty) {
        recovered.add(release);
        continue;
      }

      // Both the playback and the resource API can return the upgrade clip.
      // Ask the resource failover API for the original file instead.
      final link = asString(item['resourceLink'] ?? item['url']);
      if (link == null || !MovieBoxParser.isTrailerOrNoticeUrl(link)) continue;

      final resourceId = release.resourceId;
      if (resourceId == null) continue;

      final recoveredRelease = await _recoverResource(
        id,
        resourceId,
        link,
        release,
      );
      if (recoveredRelease == null) continue;
      recovered.add(recoveredRelease);
    }
    return recovered;
  }

  /// Asks the resource failover API for the original file of a resource.
  Future<Release?> _recoverResource(
    String subjectId,
    String resourceId,
    String failedUrl,
    Release original,
  ) async {
    try {
      final payload = await get(
        resourcePositionPath(subjectId, resourceId, failedUrl),
      );
      return MovieBoxParser.resourcePositionJsonToRelease(
        payload,
        original,
        userAgent: _userAgent,
      );
    } catch (error) {
      AppLogger.warn('moviebox direct file recovery failed: $error');
      return null;
    }
  }

  /// Re-resolves a MovieBox release to a fresh signed URL.
  ///
  /// The detector links carry a `?sign=<token>&t=<expiry>` query, so a link
  /// that was listed a while ago can already be stale. Refreshing right
  /// before playback guarantees a working URL.
  Future<PlaybackSource?> refreshSource(
    String subjectId,
    String resourceId,
  ) async {
    if (subjectId.trim().isEmpty || resourceId.trim().isEmpty) return null;
    try {
      final payload = await detailsPayload(subjectId);
      final releases = MovieBoxParser.detectorJsonToReleases(
        payload,
        season: 0,
        episode: 0,
        userAgent: _userAgent,
      );
      for (final release in releases) {
        if (release.resourceId != resourceId) continue;
        final mirror = release.mirrors.isEmpty ? null : release.mirrors.first;
        if (mirror == null) continue;
        return PlaybackSource(
          provider: ProviderKind.moviebox,
          url: mirror.resolverUrl,
          // The CDN answers 429 when a Referer is sent and expects the
          // MovieBox app user agent.
          headers: [MapEntry('User-Agent', _userAgent)],
          sourceLabel: mirror.label,
          maxHeight: release.resolutionU64 > 0 ? release.resolutionU64 : null,
        );
      }
    } catch (error) {
      AppLogger.warn('moviebox source refresh failed: $error');
    }
    return null;
  }

  @override
  Future<List<Release>> episodeStreams(
    String id,
    int season,
    int episode,
  ) async {
    // The details payload still carries the real media links in
    // `resourceDetectors[].resolutionList[]`, while `play-info` only
    // returns the site trailer. Prefer the detector links and keep the
    // play-info / resource path as a fallback for the case that upstream
    // restores the signed manifests.
    final detectorReleases = await _detectorReleases(id, season, episode);
    if (detectorReleases.isNotEmpty) return detectorReleases;

    final results = await Future.wait<Object?>([
      playInfo(id, season, episode).catchError((Object error) => null),
      _episodeResources(id, season, episode).catchError((Object error) => null),
    ]);

    final releases = <Release>[];
    final seenUrls = <String>{};

    final playInfoPayload = results[0];
    if (playInfoPayload != null) {
      for (final release in MovieBoxParser.playInfoJsonToReleases(
        playInfoPayload,
        season: season,
        episode: episode,
        userAgent: _userAgent,
      )) {
        final url = release.directUrl;
        if (url != null) {
          final base = url.split('?').first;
          if (base.isNotEmpty) seenUrls.add(base);
        }
        releases.add(release);
      }
    }

    final resourcesPayload = results[1];
    if (resourcesPayload != null) {
      for (final release in await _recoverTrailers(
        resourcesPayload,
        season: season,
        episode: episode,
        id: id,
      )) {
        final url = release.directUrl;
        if (url != null) {
          final base = url.split('?').first;
          if (base.isNotEmpty && seenUrls.contains(base)) continue;
          if (base.isNotEmpty) seenUrls.add(base);
        }
        final matches =
            (season == 0 && episode == 0) ||
            (release.season == season && release.episode == episode) ||
            (release.season == null && release.episode == null);
        if (matches) releases.add(release);
      }
    }

    if (releases.isEmpty) {
      throw const ProviderUnavailableError(
        'MovieBox has no playable source for this entry. Some entries only '
        'carry the site trailer; try another entry of the same title or the '
        '4KHDHub or Dramachi provider.',
      );
    }

    releases.sort((left, right) {
      final byResolution = right.resolutionU64.compareTo(left.resolutionU64);
      if (byResolution != 0) return byResolution;
      return (right.sizeBytes ?? 0).compareTo(left.sizeBytes ?? 0);
    });
    return releases;
  }
}
