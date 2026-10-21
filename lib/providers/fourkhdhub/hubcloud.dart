import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/crypto/digest.dart';
import '../../data/models/release.dart';

/// A candidate playback URL extracted from a mirror page.
class MirrorCandidate {
  const MirrorCandidate(this.url, this.label, {this.headers = const []});

  final String url;
  final String label;
  final List<MapEntry<String, String>> headers;
}

/// Resolves the HubCloud / HubDrive / GreenMotors mirror chain.
///
/// The chain is identical to the reference implementation: a drive page is
/// fetched, the resolver link is followed and the final media links are
/// extracted, normalised and scored.
abstract final class HubCloud {
  static const String _downloadSelector =
      "a#download, a.btn-primary, a.btn-success, a.btn[href*='/download/'], "
      "a[href*='/download/'], a[href*='gamerxyt.com'], a[href*='hubcloud.php']";
  static const String _linkSelector = 'a[href]';

  /// Resolves a HubCloud drive page.
  static Future<List<MirrorCandidate>> resolve(
    Dio client,
    String driveUrl,
    ResolutionIntent intent,
  ) async {
    _validateResolverUrl(driveUrl);
    final driveHtml = await _fetchText(client, driveUrl);

    final resolverUrl = _findResolverLink(driveHtml);
    if (resolverUrl == null) {
      throw const MirrorResolutionException('HubCloud resolver link missing');
    }

    final resolverHtml = await _fetchText(client, resolverUrl);
    final document = html_parser.parse(resolverHtml);

    final candidates = <MirrorCandidate>[];
    for (final url in extractScriptPixeldrainUrls(resolverHtml)) {
      candidates.add(MirrorCandidate(url, 'PixelDrain'));
    }

    for (final node in document.querySelectorAll(_linkSelector)) {
      final href = node.attributes['href'];
      if (href == null) continue;
      final label = node.text.trim();
      final unwrapped = _unwrapWatchOnlineUrl(href);
      if (unwrapped != null) {
        final valid = validatePlaybackUrl(unwrapped);
        if (valid != null) {
          candidates.add(MirrorCandidate(valid, 'Watch Online'));
        }
        continue;
      }
      final valid = validatePlaybackUrl(href);
      if (valid == null) continue;
      final url = pixeldrainApiUrl(valid) ?? valid;
      candidates.add(MirrorCandidate(url, label.isEmpty ? 'Direct' : label));
    }

    candidates.sort(
      (a, b) => score(
        b.url,
        b.label,
        intent,
      ).compareTo(score(a.url, a.label, intent)),
    );

    final seen = <String>{};
    final resolved = <MirrorCandidate>[];
    for (final candidate in candidates) {
      if (!seen.add(candidate.url)) continue;
      resolved.add(candidate);
    }
    if (resolved.isEmpty) {
      throw const MirrorResolutionException('no candidates found');
    }
    return resolved;
  }

  /// Resolves a HubDrive page by extracting the nested HubCloud link.
  static Future<List<MirrorCandidate>> resolveHubDrive(
    Dio client,
    String driveUrl,
    ResolutionIntent intent,
  ) async {
    _validateHubDriveUrl(driveUrl);
    final html = await _fetchText(client, driveUrl);
    final hubcloudUrl = _extractHubcloudDriveUrl(html);
    if (hubcloudUrl == null) {
      throw const MirrorResolutionException('HubDrive HubCloud mirror missing');
    }
    return resolve(client, hubcloudUrl, intent);
  }

  /// Resolves a GreenMotors page by unpacking its obfuscated payload.
  static Future<List<MirrorCandidate>> resolveGreenMotors(
    Dio client,
    String driveUrl,
    ResolutionIntent intent,
  ) async {
    _validateGreenMotorsUrl(driveUrl);
    final html = await _fetchText(client, driveUrl);
    final targetUrl = _unpackGreenmotorsUrl(html);
    if (targetUrl == null) {
      throw const MirrorResolutionException(
        'GreenMotors mirror target missing',
      );
    }
    if (targetUrl.contains('hubcloud.')) {
      return resolve(client, targetUrl, intent);
    }
    if (targetUrl.contains('hubdrive.')) {
      return resolveHubDrive(client, targetUrl, intent);
    }
    final valid = validatePlaybackUrl(targetUrl);
    if (valid == null) {
      throw const MirrorResolutionException('invalid GreenMotors target');
    }
    return [MirrorCandidate(valid, 'Direct')];
  }

  /// Validates a playback URL, rejecting insecure or private destinations.
  static String? validatePlaybackUrl(String raw) {
    final url = _normalizePlaybackUrl(raw);
    if (url == null) return null;
    if (url.scheme != 'https' || url.host.isEmpty) return null;
    final host = url.host.toLowerCase();
    final path = url.path.toLowerCase();

    if (host == 'localhost' || host.endsWith('.local')) return null;
    if (_isPrivateHost(host)) return null;
    if (path.endsWith('.zip')) return null;
    if (path.contains('login.php')) return null;
    if (path.contains('logout')) return null;
    if (host.contains('greenmotors.') || host.contains('greenmountmotors.')) {
      return null;
    }
    return url.toString();
  }

  /// Ranks a mirror: lower scores are preferred.
  static int score(String url, String label, ResolutionIntent intent) {
    final value = '$url $label'.toLowerCase();
    switch (intent) {
      case ResolutionIntent.playback:
        if (_containsAny(value, const [
          'pixel.hubcloud.',
          'googleusercontent.com',
          'googlevideo.com',
          'cloudflarestorage.com',
          'r2.cloudflarestorage.com',
          'fsl server',
          '10gbps',
          'r2.dev',
          'watch online',
        ])) {
          return 0;
        }
        if (_containsAny(value, const [
          'storage.googleapis.com',
          'hubcloud.cx/re/',
          'hubcloud.fans/re/',
        ])) {
          return 1;
        }
        if (value.contains('pixeldrain')) return 2;
        if (_containsAny(value, const [
          'testzip.php',
          'vcloud.php',
          'drive.php',
          'gpdl.',
        ])) {
          return 3;
        }
        return 4;
      case ResolutionIntent.download:
        if (_containsAny(value, const [
          'pixel.hubcloud.',
          'googleusercontent.com',
          'cloudflarestorage.com',
          'r2.cloudflarestorage.com',
          'fsl server',
          'r2.dev',
          'workers.dev',
          'watch online',
        ])) {
          return 0;
        }
        if (_containsAny(value, const [
          'storage.googleapis.com',
          'hubcloud.cx/re/',
          'hubcloud.fans/re/',
        ])) {
          return 1;
        }
        if (value.contains('pixeldrain')) return 2;
        if (_containsAny(value, const [
          'googlevideo.com',
          'testzip.php',
          'vcloud.php',
          'drive.php',
          'gpdl.',
        ])) {
          return 3;
        }
        return 4;
    }
  }

  /// Extracts PixelDrain links embedded in inline scripts.
  static List<String> extractScriptPixeldrainUrls(String html) {
    final urls = <String>[];
    void searchPrefix(String prefix) {
      var remainder = html;
      while (true) {
        final offset = remainder.indexOf(prefix);
        if (offset < 0) break;
        final candidate = remainder.substring(offset);
        var end = candidate.length;
        for (var i = 0; i < candidate.length; i++) {
          final c = candidate[i];
          if (c == '"' ||
              c == "'" ||
              c == '<' ||
              c == '\\' ||
              c.trim().isEmpty) {
            end = i;
            break;
          }
        }
        final url = pixeldrainApiUrl(candidate.substring(0, end));
        if (url != null && !urls.contains(url)) urls.add(url);
        remainder = candidate.substring(end);
      }
    }

    searchPrefix('https://pixeldrain.dev/u/');
    searchPrefix('https://pixeldrain.com/u/');
    searchPrefix('https://pixeldrain.dev/api/file/');
    searchPrefix('https://pixeldrain.com/api/file/');
    return urls;
  }

  /// Converts a PixelDrain page link into its direct download endpoint.
  static String? pixeldrainApiUrl(String raw) {
    final url = Uri.tryParse(raw);
    if (url == null) return null;
    final host = url.host;
    if (!host.contains('pixeldrain.')) return null;
    String? id;
    if (url.path.startsWith('/u/')) {
      id = url.path.substring(3).replaceAll(RegExp(r'^/+|/+$'), '');
    } else if (url.path.startsWith('/api/file/')) {
      id = url.path.substring(10).replaceAll(RegExp(r'^/+|/+$'), '');
    }
    if (id == null || id.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return null;
    return 'https://$host/api/file/$id?download';
  }

  /// Decodes the base64/rot13 payload used by GreenMotors.
  static String? decodeGreenmotorsPayload(String payload) {
    final step1 = base64DecodeTolerant(payload);
    if (step1 == null) return null;
    final step1String = utf8.decode(step1, allowMalformed: true);
    final step2 = base64DecodeTolerant(step1String);
    if (step2 == null) return null;
    final step2String = utf8.decode(step2, allowMalformed: true);
    final step3 = _rot13(step2String);
    final step4 = base64DecodeTolerant(step3);
    if (step4 == null) return null;
    final step4String = utf8.decode(step4, allowMalformed: true);
    try {
      final json = jsonDecode(step4String);
      if (json is! Map) return null;
      final target = json['o'];
      if (target is! String) return null;
      final bytes = base64DecodeTolerant(target);
      if (bytes == null) return null;
      return utf8.decode(bytes, allowMalformed: true);
    } on FormatException {
      return null;
    }
  }

  /// Finds the obfuscated payload inside a GreenMotors page.
  static String? extractGreenmotorsPayload(String html) {
    const needle = 's(';
    var searchIndex = 0;
    while (searchIndex < html.length) {
      final position = html.indexOf(needle, searchIndex);
      if (position < 0) break;
      final absPosition = position + needle.length;
      final rest = html.substring(absPosition).trimLeft();
      String afterKey;
      if (rest.startsWith("'o'")) {
        afterKey = rest.substring(3);
      } else if (rest.startsWith('"o"')) {
        afterKey = rest.substring(3);
      } else {
        searchIndex = absPosition;
        continue;
      }
      final afterComma = afterKey.trimLeft().startsWith(',')
          ? afterKey.trimLeft().substring(1)
          : '';
      if (afterComma.isEmpty) {
        searchIndex = absPosition;
        continue;
      }
      final trimmed = afterComma.trimLeft();
      final quote = trimmed.isEmpty ? '' : trimmed[0];
      if (quote != "'" && quote != '"') {
        searchIndex = absPosition;
        continue;
      }
      final payloadSlice = trimmed.substring(1);
      final end = payloadSlice.indexOf(quote);
      if (end >= 0) return payloadSlice.substring(0, end);
      searchIndex = absPosition;
    }
    return null;
  }

  static String? _unpackGreenmotorsUrl(String html) {
    final payload = extractGreenmotorsPayload(html);
    if (payload == null) return null;
    return decodeGreenmotorsPayload(payload);
  }

  static String? _extractHubcloudDriveUrl(String html) {
    final document = html_parser.parse(html);
    for (final node in document.querySelectorAll(_linkSelector)) {
      final raw = node.attributes['href'];
      if (raw == null) continue;
      final url = Uri.tryParse(raw);
      if (url == null) continue;
      if (url.host.contains('hubcloud.') && url.path.startsWith('/drive/')) {
        return url.toString();
      }
    }
    return null;
  }

  static String? _unwrapWatchOnlineUrl(String raw) {
    final url = Uri.tryParse(raw);
    if (url == null) return null;
    if (!url.host.contains('pages.dev')) return null;
    final encoded = url.queryParameters['u'];
    if (encoded == null) return null;
    final decoded = base64DecodeTolerant(encoded);
    if (decoded == null) return null;
    final value = utf8.decode(decoded, allowMalformed: true);
    if (value.startsWith('https://')) return value;
    return null;
  }

  static String? _findResolverLink(String html) {
    final document = html_parser.parse(html);
    for (final node in document.querySelectorAll(_downloadSelector)) {
      final href = node.attributes['href'];
      if (href != null && href.startsWith('https://')) return href;
    }
    return null;
  }

  static Future<String> _fetchText(Dio client, String url) async {
    final response = await client.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw MirrorResolutionException('HTTP status $status for $url');
    }
    return response.data ?? '';
  }

  static void _validateResolverUrl(String raw) {
    final url = Uri.tryParse(raw);
    if (url == null ||
        url.scheme != 'https' ||
        !url.host.contains('hubcloud.')) {
      throw MirrorResolutionException('invalid resolver url');
    }
    if (!url.path.startsWith('/drive/')) {
      throw MirrorResolutionException('invalid resolver url');
    }
  }

  static void _validateHubDriveUrl(String raw) {
    final url = Uri.tryParse(raw);
    if (url == null ||
        url.scheme != 'https' ||
        !url.host.contains('hubdrive.')) {
      throw MirrorResolutionException('invalid hubdrive url');
    }
    if (!url.path.startsWith('/file/')) {
      throw MirrorResolutionException('invalid hubdrive url');
    }
  }

  static void _validateGreenMotorsUrl(String raw) {
    final url = Uri.tryParse(raw);
    if (url == null || url.scheme != 'https') {
      throw MirrorResolutionException('invalid greenmotors url');
    }
    final host = url.host;
    if (!host.contains('greenmotors.') && !host.contains('greenmountmotors.')) {
      throw MirrorResolutionException('invalid greenmotors url');
    }
  }

  static Uri? _normalizePlaybackUrl(String raw) {
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) return parsed;
    final schemeIndex = raw.indexOf('://');
    if (schemeIndex < 0) return null;
    final scheme = raw.substring(0, schemeIndex + 3);
    final afterScheme = raw.substring(schemeIndex + 3);
    final hostEnd = afterScheme.indexOf(RegExp(r'[/?#]'));
    final host = hostEnd < 0 ? afterScheme : afterScheme.substring(0, hostEnd);
    if (host.isEmpty || host.contains(' ')) return null;
    final rest = hostEnd < 0 ? '' : afterScheme.substring(hostEnd);
    final pathEnd = rest.indexOf(RegExp(r'[?#]'));
    final path = pathEnd < 0 ? rest : rest.substring(0, pathEnd);
    final query = pathEnd < 0 ? '' : rest.substring(pathEnd);

    final encodedPath = path
        .split('/')
        .map(
          (segment) => segment
              .split(':')
              .map((sub) => Uri.encodeComponent(sub).replaceAll('%2F', '/'))
              .join(':'),
        )
        .join('/');
    return Uri.tryParse('$scheme$host$encodedPath$query');
  }

  static bool _isPrivateHost(String host) {
    if (host == '127.0.0.1' || host == '0.0.0.0' || host == '::1') return true;
    if (host.startsWith('10.')) return true;
    if (host.startsWith('192.168.')) return true;
    if (host.startsWith('169.254.')) return true;
    if (host.startsWith('172.')) {
      final parts = host.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }

  static bool _containsAny(String value, List<String> needles) =>
      needles.any(value.contains);

  static String _rot13(String input) {
    final buffer = StringBuffer();
    for (final code in input.codeUnits) {
      if (code >= 0x61 && code <= 0x6D) {
        buffer.writeCharCode(code + 13);
      } else if (code >= 0x41 && code <= 0x4D) {
        buffer.writeCharCode(code + 13);
      } else if (code >= 0x6E && code <= 0x7A) {
        buffer.writeCharCode(code - 13);
      } else if (code >= 0x4E && code <= 0x5A) {
        buffer.writeCharCode(code - 13);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }
}

/// Raised when a mirror cannot be resolved.
class MirrorResolutionException implements Exception {
  const MirrorResolutionException(this.message);

  final String message;

  @override
  String toString() => 'MirrorResolutionException: $message';
}
