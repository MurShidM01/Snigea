import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/json/json_utils.dart';
import '../../core/network/http_client_factory.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_error.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../content_provider.dart';
import 'dramachi_parser.dart';

/// The Dramachi client.
///
/// Dramachi exposes a small JSON interface; series are addressed by a
/// composite `titleId::rip` id where the rip selects the audio version.
class DramachiClient implements ContentProvider, ReleaseProvider {
  DramachiClient({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          HttpClientFactory.create(
            connectTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 15),
          ),
      _baseUrl = baseUrl ?? DramachiParser.defaultBaseUrl;

  final Dio _dio;
  final String _baseUrl;

  String? _cachedTitleId;
  Object? _cachedTitle;
  DateTime? _cachedTitleAt;
  final Map<String, (DateTime, List<Object?>)> _episodeCache = {};

  @override
  ProviderKind get id => ProviderKind.dramachi;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsPagination: true,
    supportsSeries: true,
    supportsSubtitles: false,
    supportsHomepage: false,
  );

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final url =
        '$_baseUrl?interface=search&q=${Uri.encodeComponent(trimmed)}'
        '&filter=all&page=${page < 1 ? 1 : page}';
    final payload = await _getJson(url);
    return DramachiParser.searchToCatalog(payload);
  }

  @override
  Future<MediaDetails> details(String id) async {
    final (titleId, targetRip) = _splitId(id);
    if (titleId.isEmpty) throw const NotFoundError();

    final data = await _fetchTitleDetails(titleId);
    final album = asMap(asList(asMap(data)?['album'])?.first);
    if (album == null) throw const NotFoundError();

    final content = asString(album['content']);
    final isMovie =
        content != null &&
        (content.toLowerCase() == 'movies' || content.toLowerCase() == 'movie');
    final mediaType = isMovie ? MediaType.movie : MediaType.series;

    final thumb = asString(album['thumb'])?.trim();
    final posterUrl = (thumb == null || thumb.isEmpty)
        ? null
        : '${DramachiParser.imageCdnBase}$thumb';

    final genres = (asString(album['genres']) ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final stars = (asList(asMap(data)?['cast']) ?? const [])
        .map((c) => asString(asMap(c)?['name']))
        .whereType<String>()
        .where((n) => n.trim().isNotEmpty)
        .toList();

    final seasonsMap = asMap(asMap(data)?['seasons']);
    final seasonKeys = seasonsMap?.keys.toList() ?? <String>[];
    seasonKeys.sort((a, b) {
      final left = DramachiParser.extractLeadingSeasonNumber(a);
      final right = DramachiParser.extractLeadingSeasonNumber(b);
      if (left == null && right == null) return a.compareTo(b);
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });

    final dubs = <AudioTrackOption>[];
    for (final key in seasonKeys) {
      final versions = asList(asMap(seasonsMap![key])?['versions']) ?? const [];
      for (final version in versions) {
        final versionMap = asMap(version);
        if (versionMap == null) continue;
        final versionName = asString(versionMap['version_name']) ?? '';
        final rip = asString(versionMap['rip']) ?? '';
        final label = (seasonsMap.length > 1)
            ? '$key: $versionName'
            : versionName;
        dubs.add(
          AudioTrackOption(
            subjectId: '$titleId::$rip',
            language: versionName,
            label: label,
          ),
        );
      }
    }
    dubs.sort(
      (a, b) => _dubPriority(a.language).compareTo(_dubPriority(b.language)),
    );

    final seasons = <Season>[];
    if (mediaType == MediaType.series && seasonsMap != null) {
      for (final key in seasonKeys) {
        final versions =
            asList(asMap(seasonsMap[key])?['versions']) ?? const [];
        String? rip;
        if (targetRip != null) {
          for (final version in versions) {
            if (asString(asMap(version)?['rip']) == targetRip) {
              rip = targetRip;
              break;
            }
          }
        }
        rip ??= asString(asMap(versions.first)?['rip']);
        rip ??= key;

        final seasonNumber =
            DramachiParser.extractLeadingSeasonNumber(key) ?? 1;
        final episodes = await _fetchEpisodes(titleId, rip);
        final episodeModels = <Episode>[];
        if (episodes.isEmpty) {
          episodeModels.add(Episode(season: seasonNumber, number: 1));
        } else {
          final seen = <int>{};
          for (var index = 0; index < episodes.length; index++) {
            final fileTitle =
                asString(asMap(episodes[index])?['f_title']) ?? '';
            final number =
                DramachiParser.parseEpisodeNumber(fileTitle) ?? index + 1;
            if (!seen.add(number)) continue;
            episodeModels.add(
              Episode(
                season: seasonNumber,
                number: number,
                title: DramachiParser.cleanEpisodeTitle(fileTitle),
              ),
            );
          }
          episodeModels.sort((a, b) => a.number.compareTo(b.number));
        }
        seasons.add(Season(number: seasonNumber, episodes: episodeModels));
      }
    }

    final primaryId = targetRip != null ? '$titleId::$targetRip' : titleId;

    return MediaDetails(
      id: ProviderMediaId(provider: ProviderKind.dramachi, value: primaryId),
      title: asString(album['title']) ?? 'Unknown',
      mediaType: mediaType,
      year: _nonEmpty(asString(album['year'])),
      description: _nonEmpty(asString(album['storyline'])),
      tagline: null,
      imdbRating: null,
      director: _nonEmpty(asString(album['director'])),
      stars: stars.isEmpty ? null : stars.join(', '),
      prints: null,
      audios: null,
      posterUrl: posterUrl,
      duration: null,
      genres: genres,
      seasons: seasons,
      dubs: dubs,
    );
  }

  @override
  Future<List<Release>> episodeStreams(
    String id,
    int season,
    int episode,
  ) async {
    final (titleId, targetRip) = _splitId(id);
    if (titleId.isEmpty) throw const NotFoundError();

    String ripToQuery;
    if (targetRip != null) {
      ripToQuery = targetRip;
    } else {
      final data = await _fetchTitleDetails(titleId);
      final seasonsMap = asMap(asMap(data)?['seasons']);
      String? resolved;
      if (seasonsMap != null) {
        if (season > 0) {
          final group =
              seasonsMap['Season ${season.toString().padLeft(2, '0')}'];
          final versions = asList(asMap(group)?['versions']) ?? const [];
          if (versions.isNotEmpty) {
            resolved = asString(asMap(versions.first)?['rip']);
          }
        }
        final firstSeason = seasonsMap.values.first;
        final firstVersions =
            asList(asMap(firstSeason)?['versions']) ?? const [];
        resolved ??= asString(asMap(firstVersions.first)?['rip']);
      }
      ripToQuery =
          resolved ??
          (season > 0
              ? 'Season ${season.toString().padLeft(2, '0')}'
              : 'hd Rip');
    }

    final episodes = await _fetchEpisodes(titleId, ripToQuery);
    if (episodes.isEmpty) return const [];

    final matched = <Map<String, Object?>>[];
    if (season == 0 && episode == 0) {
      matched.addAll(episodes);
    } else {
      final exact = episodes.where((ep) {
        return DramachiParser.parseEpisodeNumber(
              asString(ep['f_title']) ?? '',
            ) ==
            episode;
      }).toList();
      if (exact.isNotEmpty) {
        matched.addAll(exact);
      } else if (episode > 0 && episode <= episodes.length) {
        matched.add(episodes[episode - 1]);
      }
    }

    final releases = <Release>[];
    for (final ep in matched) {
      final fid = asString(ep['fid']);
      final disk = asString(ep['disk']);
      if (fid == null || fid.isEmpty || disk == null || disk.isEmpty) continue;
      try {
        final (streamUrl, filename) = await _fetchFileStream(fid, disk);
        releases.add(
          DramachiParser.toRelease(
            filename: filename,
            url: streamUrl,
            quality: asString(ep['quality']),
            size: asString(ep['size']),
            season: season > 0 ? season : null,
            episode: episode > 0 ? episode : null,
            resourceId: fid,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    releases.sort((a, b) => b.resolutionI64.compareTo(a.resolutionI64));
    return releases;
  }

  /// Resolves the direct CDN URL of a file.
  Future<(String, String)> _fetchFileStream(String fid, String disk) async {
    final url =
        '$_baseUrl?interface=getFile&fid=${Uri.encodeComponent(fid)}'
        '&findex=${Uri.encodeComponent(disk)}';
    final payload = await _getJson(url);
    final map = asMap(payload);

    final hostInfo = asMap(map?['hostInfo']);
    if (hostInfo == null) {
      throw const ParsingError('missing hostInfo in getFile');
    }
    final fileInfo = asMap(asList(map?['fileInfo'])?.first);
    if (fileInfo == null) throw const NotFoundError();

    final rawUrl = asString(fileInfo['url']);
    if (rawUrl == null) throw const ParsingError('missing url in fileInfo');

    final filename =
        asString(fileInfo['filename']) ??
        asString(fileInfo['f_title']) ??
        '$fid.mkv';

    final host = (asString(hostInfo['host']) ?? '').replaceAll(
      RegExp(r'/$'),
      '',
    );
    final streamUrl =
        'https://$host/cdn/${rawUrl.replaceFirst(RegExp(r'^/+'), '')}';
    return (streamUrl, filename);
  }

  Future<Object?> _fetchTitleDetails(String titleId) async {
    final cachedAt = _cachedTitleAt;
    if (_cachedTitleId == titleId &&
        _cachedTitle != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(seconds: 60)) {
      return _cachedTitle;
    }
    final url =
        '$_baseUrl?interface=title_v2&id=${Uri.encodeComponent(titleId)}';
    final payload = await _getJson(url);
    _cachedTitleId = titleId;
    _cachedTitle = payload;
    _cachedTitleAt = DateTime.now();
    return payload;
  }

  Future<List<Map<String, Object?>>> _fetchEpisodes(
    String titleId,
    String rip,
  ) async {
    final key = '$titleId::$rip';
    final cached = _episodeCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(seconds: 60)) {
      return cached.$2.cast<Map<String, Object?>>();
    }

    final url =
        '$_baseUrl?interface=eplist&season=${Uri.encodeComponent(rip)}'
        '&id=${Uri.encodeComponent(titleId)}';
    final payload = await _getJson(url);
    final episodes = (asList(asMap(payload)?['episode_list']) ?? const [])
        .map(asMap)
        .whereType<Map<String, Object?>>()
        .toList();
    episodes.sort((a, b) {
      final left = DramachiParser.parseEpisodeNumber(
        asString(a['f_title']) ?? '',
      );
      final right = DramachiParser.parseEpisodeNumber(
        asString(b['f_title']) ?? '',
      );
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
    if (_episodeCache.length >= 16) _episodeCache.clear();
    _episodeCache[key] = (DateTime.now(), episodes.cast<Object?>());
    return episodes;
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
      final data = response.data;
      if (data is String) {
        // The API does not always announce the JSON content type, so the
        // body is decoded by hand.
        try {
          return jsonDecode(data);
        } on FormatException catch (error) {
          throw ParsingError(error.message);
        }
      }
      return data;
    } on DioException catch (error) {
      throw NetworkError(error.message ?? error.type.name);
    }
  }

  static (String, String?) _splitId(String id) {
    final index = id.indexOf('::');
    if (index < 0) return (id.trim(), null);
    return (id.substring(0, index).trim(), id.substring(index + 2).trim());
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _dubPriority(String language) {
    final lower = language.toLowerCase();
    if (lower.contains('original') || lower == 'orig') return 0;
    if (lower.contains('english') || lower.contains('eng')) return 1;
    if (lower.contains('dub')) return 2;
    return 3;
  }
}
