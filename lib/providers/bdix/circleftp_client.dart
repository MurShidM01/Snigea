import 'package:dio/dio.dart';

import '../../core/json/json_utils.dart';
import '../../core/network/http_client_factory.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_error.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../content_provider.dart';
import 'bdix_common.dart';

/// The CircleFTP client.
///
/// CircleFTP is reachable through a BDIX mirror, therefore it only works from
/// an ISP network that peers with the BDIX exchange.
class CircleFtpClient implements ContentProvider, ReleaseProvider {
  CircleFtpClient({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          HttpClientFactory.create(
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
      _baseUrl = baseUrl ?? apiUrl;

  /// The web front-end of the mirror.
  static const String baseUrl = 'http://new.circleftp.net:5000';

  /// The JSON API of the mirror.
  static const String apiUrl = 'http://new.circleftp.net:5000/api';

  /// Where the poster images are hosted.
  static const String uploadsUrl = 'http://new.circleftp.net:5000/uploads/';

  final Dio _dio;
  final String _baseUrl;

  String? _cachedPostId;
  Object? _cachedPost;
  DateTime? _cachedPostAt;

  @override
  ProviderKind get id => ProviderKind.bdixCircleFtp;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsPagination: false,
    supportsSeries: true,
    supportsSubtitles: false,
    supportsHomepage: false,
  );

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async {
    final url =
        '$_baseUrl/posts?searchTerm=${Uri.encodeQueryComponent(query)}'
        '&order=desc';
    final payload = await _getJson(url);
    return _searchToCatalog(payload);
  }

  @override
  Future<MediaDetails> details(String id) async {
    final json = await _fetchPost(id);
    final map = asMap(json) ?? const <String, Object?>{};

    final title = asString(map['title'] ?? map['name']) ?? 'Unknown';
    final type = asString(map['type']) ?? '';
    final mediaType = type == 'series' ? MediaType.series : MediaType.movie;

    final yearValue = map['year'];
    final year = yearValue is num ? yearValue.toString() : asString(yearValue);

    final image = asString(map['image'] ?? map['imageSm']);
    final posterUrl = image == null ? null : '$uploadsUrl$image';

    final seasons = <Season>[];
    if (mediaType == MediaType.series) {
      final content = asList(map['content']) ?? const [];
      for (var seasonIndex = 0; seasonIndex < content.length; seasonIndex++) {
        final seasonMap = asMap(content[seasonIndex]);
        final episodes = <Episode>[];
        final episodeList = asList(seasonMap?['episodes']) ?? const [];
        for (
          var episodeIndex = 0;
          episodeIndex < episodeList.length;
          episodeIndex++
        ) {
          final episodeMap = asMap(episodeList[episodeIndex]);
          episodes.add(
            Episode(
              season: seasonIndex + 1,
              number: episodeIndex + 1,
              title: asString(episodeMap?['title']),
            ),
          );
        }
        seasons.add(Season(number: seasonIndex + 1, episodes: episodes));
      }
    }

    final description = asString(map['metaData']);
    final duration = asString(map['watchTime']);

    final genres = <String>[];
    for (final category in asList(map['categories']) ?? const []) {
      final name = asString(asMap(category)?['name']);
      if (name != null) genres.add(name);
    }

    final titleLower = (asString(map['title']) ?? '').toLowerCase();
    final audios = _firstMatch(titleLower, const [
      ('hindi', 'Hindi'),
      ('bengali', 'Bengali'),
      ('bangla', 'Bengali'),
      ('english', 'English'),
      ('tamil', 'Tamil'),
      ('telugu', 'Telugu'),
      ('malayalam', 'Malayalam'),
      ('korean', 'Korean'),
      ('dual audio', 'Dual Audio'),
      ('multi audio', 'Multi Audio'),
    ]);
    final prints = _firstMatch(titleLower, const [
      ('cam', 'CAM'),
      ('hdcam', 'CAM'),
      ('hdtc', 'HDTC'),
      ('hd rip', 'HDRip'),
      ('hdrip', 'HDRip'),
      ('webrip', 'WEBRip'),
      ('web-rip', 'WEBRip'),
      ('webdl', 'WEB-DL'),
      ('web-dl', 'WEB-DL'),
      ('bluray', 'BluRay'),
      ('brrip', 'BluRay'),
    ]);

    return MediaDetails(
      id: ProviderMediaId(provider: ProviderKind.bdixCircleFtp, value: id),
      title: title,
      mediaType: mediaType,
      year: year,
      description: description,
      tagline: null,
      imdbRating: null,
      director: null,
      stars: null,
      prints: prints,
      audios: audios,
      posterUrl: posterUrl,
      duration: duration,
      genres: genres,
      seasons: seasons,
      dubs: const [],
    );
  }

  @override
  Future<List<Release>> episodeStreams(
    String id,
    int season,
    int episode,
  ) async {
    final json = await _fetchPost(id);
    final map = asMap(json) ?? const <String, Object?>{};
    final releases = <Release>[];

    final type = asString(map['type']) ?? '';
    final qualityText = asString(map['quality']) ?? 'HD';
    final quality = detectBdixResolution(qualityText) ?? qualityText;

    final title = asString(map['title']) ?? '';
    final codec = detectBdixCodec(title);
    final language = detectBdixAudioLanguage(title);

    if (type == 'series') {
      if (season <= 0 || episode <= 0) return const [];
      final content = asList(map['content']) ?? const [];
      if (season > content.length) return const [];
      final seasonMap = asMap(content[season - 1]);
      final episodes = asList(seasonMap?['episodes']) ?? const [];
      if (episode > episodes.length) return const [];
      final episodeMap = asMap(episodes[episode - 1]);
      final link = asString(episodeMap?['link']);
      if (link == null) return const [];
      final filename = _decodeFileName(link);
      releases.add(
        Release(
          provider: ProviderKind.bdixCircleFtp,
          filename: filename,
          quality: quality,
          codec: codec,
          language: language,
          sizeBytes: await _fetchSize(link),
          season: season,
          episode: episode,
          mirrors: [
            SourceMirror(
              label: 'CircleFTP',
              resolverUrl: link,
              headers: const [],
              directFile: true,
            ),
          ],
        ),
      );
    } else {
      final content = asString(map['content']);
      if (content == null) return const [];
      releases.add(
        Release(
          provider: ProviderKind.bdixCircleFtp,
          filename: _decodeFileName(content),
          quality: quality,
          codec: codec,
          language: language,
          sizeBytes: await _fetchSize(content),
          mirrors: [
            SourceMirror(
              label: 'CircleFTP',
              resolverUrl: content,
              headers: const [],
              directFile: true,
            ),
          ],
        ),
      );
    }
    return releases;
  }

  Future<Object?> _fetchPost(String id) async {
    final cachedAt = _cachedPostAt;
    if (_cachedPostId == id &&
        _cachedPost != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(seconds: 60)) {
      return _cachedPost;
    }
    final payload = await _getJson('$_baseUrl/posts/$id');
    _cachedPostId = id;
    _cachedPost = payload;
    _cachedPostAt = DateTime.now();
    return payload;
  }

  Future<int?> _fetchSize(String link) async {
    try {
      final response = await _dio.head<Object?>(
        link,
        options: Options(
          validateStatus: (status) => status != null && status < 600,
          receiveTimeout: const Duration(milliseconds: 1200),
        ),
      );
      final length = response.headers.value('content-length');
      return length == null ? null : int.tryParse(length);
    } catch (_) {
      return null;
    }
  }

  Future<Object?> _getJson(String url) async {
    try {
      final response = await _dio.get<Object?>(
        url,
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        if (status == 404) throw const NotFoundError();
        throw ProviderUnavailableError('HTTP status $status');
      }
      return response.data;
    } on DioException catch (error) {
      throw NetworkError(error.message ?? error.type.name);
    }
  }

  static List<CatalogItem> _searchToCatalog(Object? payload) {
    final map = asMap(payload);
    final posts = asList(map?['posts']) ?? const [];
    final items = <CatalogItem>[];
    for (final entry in posts) {
      final post = asMap(entry);
      if (post == null) continue;
      final id = asInt(post['id']);
      if (id == null) continue;
      final title = asString(post['title'] ?? post['name']) ?? 'Unknown';
      final type = asString(post['type']);
      final mediaType = type == 'series' ? MediaType.series : MediaType.movie;
      final yearValue = post['year'];
      final year = yearValue is num
          ? yearValue.toString()
          : asString(yearValue);
      final image = asString(post['image'] ?? post['imageSm']);
      items.add(
        CatalogItem(
          id: ProviderMediaId(
            provider: ProviderKind.bdixCircleFtp,
            value: id.toString(),
          ),
          title: title,
          mediaType: mediaType,
          year: year,
          posterUrl: image == null ? null : '$uploadsUrl$image',
        ),
      );
    }
    return items;
  }

  static String _decodeFileName(String link) {
    final name = link.split('/').last;
    return name
        .replaceAll('%20', ' ')
        .replaceAll('%28', '(')
        .replaceAll('%29', ')')
        .replaceAll('%5B', '[')
        .replaceAll('%5D', ']');
  }

  static String? _firstMatch(String haystack, List<(String, String)> options) {
    for (final option in options) {
      if (haystack.contains(option.$1)) return option.$2;
    }
    return null;
  }
}
