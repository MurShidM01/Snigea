import 'package:dio/dio.dart';

import '../../core/json/json_utils.dart';
import '../../core/network/http_client_factory.dart';
import '../../core/network/user_agents.dart';
import '../../core/text/cleaners.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_error.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../content_provider.dart';
import 'bdix_common.dart';

/// The DhakaFlix client.
///
/// DhakaFlix is a local BDIX file index; the client queries every reachable
/// server of the exchange and merges the results.
class DhakaFlixClient implements ContentProvider, ReleaseProvider {
  DhakaFlixClient({Dio? dio})
    : _dio =
          dio ??
          HttpClientFactory.create(
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
            userAgent: UserAgents.browser,
          );

  /// The servers of the BDIX exchange, with the path they are mounted on.
  static const List<(String, String)> servers = [
    ('http://172.16.50.7', '/DHAKA-FLIX-7/'),
    ('http://172.16.50.14', '/DHAKA-FLIX-14/'),
    ('http://172.16.50.12', '/DHAKA-FLIX-12/'),
    ('http://172.16.50.9', '/DHAKA-FLIX-9/'),
  ];

  /// A server is skipped for one minute after a failure.
  static const Duration deadServerTtl = Duration(seconds: 60);

  final Dio _dio;
  final Map<String, DateTime> _recentFails = {};

  @override
  ProviderKind get id => ProviderKind.bdixDhakaFlix;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsPagination: false,
    supportsSeries: false,
    supportsSubtitles: false,
    supportsHomepage: false,
  );

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async {
    final healthy = _healthyServers();
    if (healthy.isEmpty) {
      throw const NetworkError('No BDIX server reachable');
    }

    final results = await Future.wait<List<(CatalogItem, int)>>(
      healthy.map((server) => _searchServer(server.$1, server.$2, query)),
    );

    final merged = <(CatalogItem, int)>[];
    for (final result in results) {
      merged.addAll(result);
    }
    final deduped = _dedupBestQuality(merged);

    // Poster artwork is fetched lazily for the first results.
    final limited = deduped.take(20).toList();
    for (var index = 0; index < limited.length; index++) {
      final poster = await _fetchPoster(limited[index].$1.id.value);
      if (poster != null) {
        limited[index] = (
          CatalogItem(
            id: limited[index].$1.id,
            title: limited[index].$1.title,
            mediaType: limited[index].$1.mediaType,
            year: limited[index].$1.year,
            posterUrl: poster,
            seasonCount: limited[index].$1.seasonCount,
          ),
          limited[index].$2,
        );
      }
    }
    return limited.map((entry) => entry.$1).toList();
  }

  @override
  Future<MediaDetails> details(String id) async {
    final parsed = parseDhakaFlixId(id);
    var title = 'Unknown';
    if (parsed != null) {
      final parts = parsed.$2.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        title = Uri.decodeComponent(parts.last);
      }
    }
    final (cleanTitle, year) = parseTitleAndYear(title);

    return MediaDetails(
      id: ProviderMediaId(provider: ProviderKind.bdixDhakaFlix, value: id),
      title: cleanTitle,
      mediaType: MediaType.movie,
      year: year,
      description: null,
      tagline: null,
      imdbRating: null,
      director: null,
      stars: null,
      prints: null,
      audios: null,
      posterUrl: null,
      duration: null,
      genres: const [],
      seasons: const [],
      dubs: const [],
    );
  }

  @override
  Future<List<Release>> episodeStreams(
    String id,
    int season,
    int episode,
  ) async {
    final releases = <Release>[];
    final parsed = parseDhakaFlixId(id);
    if (parsed == null) return releases;

    final baseUrl = parsed.$1;
    final path = parsed.$2;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return releases;

    var apiHref = '/';
    for (final server in servers) {
      if (server.$1 == baseUrl) {
        apiHref = server.$2;
        break;
      }
    }

    final payload = await _postJson('$baseUrl$apiHref', {
      'action': 'get',
      'items': {'href': path, 'what': 1},
    });

    for (final entry in asList(asMap(payload)?['items']) ?? const []) {
      final item = asMap(entry);
      if (item == null) continue;
      final itemHref = asString(item['href']);
      final size = asInt(item['size']);
      if (itemHref == null || size == null) continue;

      final filename = Uri.decodeComponent(itemHref.split('/').last);
      final lower = filename.toLowerCase();
      if (!lower.endsWith('.mkv') &&
          !lower.endsWith('.mp4') &&
          !lower.endsWith('.avi') &&
          !lower.endsWith('.webm')) {
        continue;
      }

      releases.add(
        Release(
          provider: ProviderKind.bdixDhakaFlix,
          filename: filename,
          quality: detectBdixResolution(lower) ?? 'HD',
          codec: detectBdixCodec(lower),
          language: detectBdixAudioLanguage(lower),
          sizeBytes: size,
          mirrors: [
            SourceMirror(
              label: 'DhakaFlix',
              resolverUrl: '$baseUrl$itemHref',
              headers: const [],
              directFile: true,
            ),
          ],
        ),
      );
    }
    return releases;
  }

  Future<List<(CatalogItem, int)>> _searchServer(
    String baseUrl,
    String href,
    String query,
  ) async {
    try {
      final payload = await _postJson('$baseUrl$href', {
        'action': 'get',
        'search': {'href': href, 'pattern': query, 'ignorecase': true},
      });
      final results = <(CatalogItem, int)>[];
      for (final entry in asList(asMap(payload)?['search']) ?? const []) {
        final itemHref = asString(asMap(entry)?['href']);
        if (itemHref == null) continue;
        final isDirectory = itemHref.endsWith('/');
        final parts = itemHref.split('/').where((p) => p.isNotEmpty).toList();
        if (!isDirectory && parts.length > 1) {
          parts.removeLast();
        }
        final folderPath = '/${parts.join('/')}/';
        if (parts.isEmpty) continue;
        final name = Uri.decodeComponent(parts.last);
        final quality = _qualityScore(name);
        final (cleanTitle, year) = parseTitleAndYear(name);
        results.add((
          CatalogItem(
            id: ProviderMediaId(
              provider: ProviderKind.bdixDhakaFlix,
              value:
                  '$baseUrl:$href'
                  '${folderPath.replaceFirst(href, '')}',
            ),
            title: cleanTitle,
            mediaType: MediaType.movie,
            year: year,
          ),
          quality,
        ));
      }
      return results;
    } on DioException {
      _recentFails[baseUrl] = DateTime.now();
      return const [];
    }
  }

  Future<String?> _fetchPoster(String id) async {
    final parsed = parseDhakaFlixId(id);
    if (parsed == null) return null;
    final baseUrl = parsed.$1;
    final parts = parsed.$2.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;

    final apiHref = '/${parts.first}/';
    try {
      final payload = await _postJson('$baseUrl$apiHref', {
        'action': 'get',
        'items': {'href': parsed.$2, 'what': 1},
      });
      for (final entry in asList(asMap(payload)?['items']) ?? const []) {
        final href = asString(asMap(entry)?['href']);
        if (href == null) continue;
        final lower = href.toLowerCase();
        if (lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png')) {
          return '$baseUrl$href';
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Object?> _postJson(String url, Object body) async {
    try {
      final response = await _dio.post<Object?>(
        url,
        data: body,
        options: Options(
          responseType: ResponseType.json,
          contentType: 'application/json',
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw ProviderUnavailableError('HTTP status $status');
      }
      return response.data;
    } on DioException catch (error) {
      throw NetworkError(error.message ?? error.type.name);
    }
  }

  List<(String, String)> _healthyServers() {
    final now = DateTime.now();
    return servers.where((server) {
      final failedAt = _recentFails[server.$1];
      return failedAt == null || now.difference(failedAt) >= deadServerTtl;
    }).toList();
  }

  static List<(CatalogItem, int)> _dedupBestQuality(
    List<(CatalogItem, int)> results,
  ) {
    final best = <String, (CatalogItem, int)>{};
    for (final entry in results) {
      final key = '${entry.$1.title.toLowerCase()}|${entry.$1.year}';
      final existing = best[key];
      if (existing == null || existing.$2 < entry.$2) {
        best[key] = entry;
      }
    }
    final output = best.values.toList()
      ..sort(
        (a, b) => a.$1.title.toLowerCase().compareTo(b.$1.title.toLowerCase()),
      );
    return output;
  }

  /// Splits a DhakaFlix id into the server address and the path.
  static (String, String)? parseDhakaFlixId(String id) {
    final position = id.lastIndexOf(':/');
    if (position < 0) return null;
    return (id.substring(0, position), id.substring(position + 1));
  }

  /// Splits a release name into a clean title and an optional year.
  static (String, String?) parseTitleAndYear(String rawTitle) {
    var title = rawTitle;
    String? year;

    final start = title.lastIndexOf('(');
    if (start >= 0) {
      final relativeEnd = title.indexOf(')', start);
      if (relativeEnd >= 0) {
        final end = start + relativeEnd;
        final yearSlice = title.substring(start + 1, end);
        final extracted = extract4DigitYear(yearSlice);
        if (extracted.length == 4 && yearSlice.trim().length == 4) {
          year = extracted;
          title = title.substring(0, start).trim();
          return (title, year);
        }
      }
    }

    final lower = title.toLowerCase();
    const qualities = [
      ' 1080p',
      ' 720p',
      ' 480p',
      ' 2160p',
      ' 4k',
      ' hd',
      ' hdrip',
      ' webrip',
      ' hdcam',
    ];
    for (final quality in qualities) {
      if (lower.endsWith(quality)) {
        title = title.substring(0, title.length - quality.length).trim();
        break;
      }
    }
    return (title, year);
  }

  static int _qualityScore(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('2160p') || lower.contains('4k')) return 3;
    if (lower.contains('1080p')) return 2;
    if (lower.contains('720p')) return 1;
    return 0;
  }
}
