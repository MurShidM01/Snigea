import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/json/json_utils.dart';
import '../../core/network/http_client_factory.dart';
import '../../core/network/user_agents.dart';
import 'addon_models.dart';

/// The HTTP client for the Stremio addon protocol.
class AddonClient {
  AddonClient({Dio? dio})
    : _dio =
          dio ??
          HttpClientFactory.create(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
            userAgent: UserAgents.addon,
          );

  final Dio _dio;

  /// Normalises a user supplied addon address into a manifest URL.
  static String normalizeManifestUrl(String raw) {
    var url = raw.trim();
    if (url.startsWith('stremio://')) {
      url = 'https://${url.substring('stremio://'.length)}';
    } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final separator = url.indexOf(RegExp(r'[?#]'));
    final base = separator < 0 ? url : url.substring(0, separator);
    final suffix = separator < 0 ? '' : url.substring(separator);
    if (!base.endsWith('/manifest.json')) {
      final trimmed = base.replaceAll(RegExp(r'/+$'), '');
      url = '$trimmed/manifest.json$suffix';
    }
    return url;
  }

  /// The base address of an addon, i.e. the manifest URL without the file.
  static String baseAddonUrl(String manifestUrl) {
    final normalized = normalizeManifestUrl(manifestUrl);
    final position = normalized.lastIndexOf('/manifest.json');
    if (position < 0) return normalized.replaceAll(RegExp(r'/+$'), '');
    return normalized.substring(0, position);
  }

  /// Downloads and parses the manifest of an addon.
  Future<AddonManifest> fetchManifest(String manifestUrl) async {
    final url = normalizeManifestUrl(manifestUrl);
    final response = await _dio.get<Object?>(
      url,
      options: Options(
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw AddonException('Manifest returned HTTP $status');
    }
    final map = asMap(response.data);
    if (map == null) throw const AddonException('Invalid manifest JSON');

    final manifest = AddonManifest.fromJson(map);
    if (manifest.name.trim().isEmpty) {
      throw const AddonException('Addon manifest is missing a valid name');
    }
    return manifest;
  }

  /// Loads a catalogue, optionally with an `extra` segment.
  Future<List<MetaItem>> fetchCatalog(
    String baseUrl,
    String type,
    String catalogId, {
    String? extra,
  }) async {
    final endpoint = (extra != null && extra.trim().isNotEmpty)
        ? '$baseUrl/catalog/$type/$catalogId/${extra.trim()}.json'
        : '$baseUrl/catalog/$type/$catalogId.json';
    final raw = await _getJson(endpoint, 'Catalog');
    return _parseMetas(raw);
  }

  /// Searches a catalogue.
  Future<List<MetaItem>> fetchCatalogSearch(
    String baseUrl,
    String type,
    String catalogId,
    String query,
  ) async {
    final encoded = Uri.encodeComponent(query.trim());
    final endpoint = '$baseUrl/catalog/$type/$catalogId/search=$encoded.json';
    final raw = await _getJson(endpoint, 'Catalog search');
    return _parseMetas(raw);
  }

  /// Loads the metadata of a title.
  Future<MetaDetail> fetchMeta(String baseUrl, String type, String id) async {
    final endpoint = '$baseUrl/meta/$type/$id.json';
    final raw = await _getJson(endpoint, 'Metadata');
    final target = asMap(raw)?['meta'];
    final map = asMap(target) ?? asMap(raw);
    if (map == null) throw const AddonException('Invalid metadata response');
    return MetaDetail.fromJson(map);
  }

  /// Loads the streams of a title.
  Future<List<StreamItem>> fetchStreams(
    String baseUrl,
    String type,
    String id,
  ) async {
    final endpoint = '$baseUrl/stream/$type/$id.json';
    final raw = await _getJson(endpoint, 'Streams');
    final streams = asList(asMap(raw)?['streams']) ?? asList(raw) ?? const [];
    return streams
        .map(asMap)
        .whereType<Map<String, Object?>>()
        .map(StreamItem.fromJson)
        .toList();
  }

  Future<Object?> _getJson(String endpoint, String label) async {
    try {
      final response = await _dio.get<Object?>(
        endpoint,
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw AddonException('$label returned HTTP $status');
      }
      final data = response.data;
      if (data is String) {
        try {
          return jsonDecode(data);
        } on FormatException {
          throw AddonException('$label returned an invalid JSON payload');
        }
      }
      return data;
    } on DioException catch (error) {
      throw AddonException(
        '$label request failed: ${error.message ?? error.type}',
      );
    }
  }

  static List<MetaItem> _parseMetas(Object? raw) {
    final map = asMap(raw);
    final list =
        asList(map?['metas']) ??
        asList(map?['items']) ??
        asList(map?['results']) ??
        asList(raw) ??
        const [];
    return list
        .map(asMap)
        .whereType<Map<String, Object?>>()
        .map(MetaItem.fromJson)
        .toList();
  }
}

/// Raised when an addon request fails.
class AddonException implements Exception {
  const AddonException(this.message);

  final String message;

  @override
  String toString() => message;
}
