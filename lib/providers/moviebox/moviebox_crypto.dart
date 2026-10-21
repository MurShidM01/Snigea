import 'dart:math';

import '../../core/crypto/digest.dart';

/// Request signing for the MovieBox API.
///
/// The upstream mobile client signs every request with an HMAC-MD5 over a
/// canonical string, using a fixed application secret. The implementation
/// below mirrors the reference Dart/Rust logic exactly so that the API keeps
/// accepting the requests.
abstract final class MovieBoxCrypto {
  /// The application secret used by the upstream Android client.
  static const List<int> defaultSecretBytes = [
    0xef, 0xa8, 0x91, 0x97, 0x4e, 0xec, 0xd3, 0x14, //
    0x8d, 0xf6, 0x3a, 0xa6, 0x11, 0x60, 0x2d, 0xef,
    0xd1, 0x01, 0x25, 0x9b, 0xa5, 0x21, 0x02, 0x2c,
    0x57, 0xae, 0x05, 0x66, 0xbd, 0x8e,
  ];

  /// Bodies longer than this are truncated before hashing.
  static const int signatureBodyMaxBytes = 102400;

  /// The `x-client-token` value: `<timestamp>,<md5 of reversed timestamp>`.
  static String generateXClientToken(int timestampMs) {
    final ts = timestampMs.toString();
    final reversed = ts.split('').reversed.join();
    return '$ts,${md5Hex(reversed)}';
  }

  /// The query string with keys sorted alphabetically.
  ///
  /// Values are decoded, matching the reference implementation which works on
  /// decoded query pairs.
  static String sortedQueryString(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final grouped = <String, List<String>>{};
    for (final pair in uri.queryParametersAll.entries) {
      grouped.putIfAbsent(pair.key, () => <String>[]).addAll(pair.value);
    }
    if (grouped.isEmpty) return '';
    final keys = grouped.keys.toList()..sort();
    final parts = <String>[];
    for (final key in keys) {
      for (final value in grouped[key]!) {
        parts.add('$key=$value');
      }
    }
    return parts.join('&');
  }

  /// Builds the canonical string that is signed.
  static String buildCanonicalString({
    required String method,
    required String url,
    String? accept,
    String? contentType,
    String? body,
    required int timestampMs,
  }) {
    final uri = Uri.tryParse(url);
    String canonicalUrl;
    if (uri != null && uri.hasScheme) {
      final path = uri.path.isEmpty ? '/' : uri.path;
      final query = sortedQueryString(url);
      canonicalUrl = query.isEmpty ? path : '$path?$query';
    } else {
      canonicalUrl = url;
    }

    String bodyHash = '';
    String bodyLength = '';
    if (body != null) {
      final bytes = body.codeUnits;
      bodyLength = bytes.length.toString();
      final truncated = bytes.length > signatureBodyMaxBytes
          ? bytes.sublist(0, signatureBodyMaxBytes)
          : bytes;
      bodyHash = md5HexBytes(truncated);
    }

    return [
      method.toUpperCase(),
      accept ?? '',
      contentType ?? '',
      bodyLength,
      timestampMs.toString(),
      bodyHash,
      canonicalUrl,
    ].join('\n');
  }

  /// The `x-tr-signature` value: `<timestamp>|2|<base64 hmac-md5>`.
  static String generateXTrSignature({
    required String method,
    required String url,
    String? accept,
    String? contentType,
    String? body,
    required int timestampMs,
  }) {
    final canonical = buildCanonicalString(
      method: method,
      url: url,
      accept: accept,
      contentType: contentType,
      body: body,
      timestampMs: timestampMs,
    );
    final signature = hmacMd5Base64(defaultSecretBytes, canonical);
    return '$timestampMs|2|$signature';
  }

  /// Builds the full set of signed headers for a request.
  static Map<String, String> buildSignedHeaders({
    required String method,
    required String url,
    String? body,
    String? authToken,
    required String userAgent,
    required String clientInfo,
    required String spoofedIp,
    required int timestampMs,
  }) {
    const accept = 'application/json';
    const contentType = 'application/json';

    final clientToken = generateXClientToken(timestampMs);
    final signature = generateXTrSignature(
      method: method,
      url: url,
      accept: accept,
      contentType: contentType,
      body: body,
      timestampMs: timestampMs,
    );

    final headers = <String, String>{
      'User-Agent': userAgent,
      'Accept': accept,
      'Content-Type': contentType,
      'Connection': 'keep-alive',
      'x-client-token': clientToken,
      'x-tr-signature': signature,
      'x-client-info': clientInfo,
      'x-client-status': '0',
      'x-forwarded-for': spoofedIp,
    };

    if (authToken != null && authToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  static const List<String> _androidVersions = [
    '9|PQ3A.190605.03081104',
    '10|QP1A.191005.007.A3',
    '11|RP1A.200720.011',
    '12|S1B.220414.015',
    '13|TQ2A.230405.003',
  ];

  static const List<String> _redmiDevices = [
    '23078RKD5C|Redmi',
    '2201117TY|Redmi',
    '2201117TG|Redmi',
    '22101316G|Redmi',
    '21121210G|Redmi',
    'M2012K11AG|Redmi',
    'M2007J20CG|Redmi',
  ];

  static const List<int> _versionCodes = [
    50020117,
    50020118,
    50020119,
    50020120,
    50020121,
  ];

  static const List<String> _networkTypes = ['NETWORK_WIFI', 'NETWORK_MOBILE'];

  static const List<String> _timezones = [
    'Asia/Kolkata',
    'Asia/Shanghai',
    'Asia/Tokyo',
    'America/New_York',
    'Europe/London',
  ];

  /// Generates a plausible device identity (user agent + client info JSON).
  static ({String userAgent, String clientInfo}) generateClientInfoAndUa() {
    final random = Random.secure();
    final android = _androidVersions[random.nextInt(_androidVersions.length)];
    final device = _redmiDevices[random.nextInt(_redmiDevices.length)];
    final versionCode = _versionCodes[random.nextInt(_versionCodes.length)];
    final network = _networkTypes[random.nextInt(_networkTypes.length)];
    final timezone = _timezones[random.nextInt(_timezones.length)];
    final gaid = _randomUuid();
    final deviceId = _randomHex(32);

    final androidVersion = android.split('|').first;
    final androidBuild = android.split('|').last;
    final deviceBrand = device.split('|').first;
    final deviceModel = device.split('|').last;

    final userAgent =
        'com.community.oneroom/$versionCode (Linux; U; Android $androidVersion; '
        'en_US; $deviceModel; Build/$androidBuild; Cronet/135.0.7012.3)';

    final clientInfo =
        '{"package_name":"com.community.oneroom",'
        '"version_name":"4.0.01.0813.03",'
        '"version_code":$versionCode,'
        '"os":"android",'
        '"os_version":"$androidVersion",'
        '"install_ch":"ps",'
        '"device_id":"$deviceId",'
        '"install_store":"ps",'
        '"gaid":"$gaid",'
        '"brand":"$deviceBrand",'
        '"model":"$deviceModel",'
        '"system_language":"en",'
        '"net":"$network",'
        '"region":"US",'
        '"timezone":"$timezone",'
        '"sp_code":"40401",'
        '"X-Play-Mode":"2"}';

    return (userAgent: userAgent, clientInfo: clientInfo);
  }

  /// A random, non-routable looking IPv4 address used for `x-forwarded-for`.
  static String randomSpoofedIp() {
    final random = Random.secure();
    const prefixes = [
      '103.241',
      '49.36',
      '117.195',
      '106.198',
      '122.162',
      '157.32',
      '182.70',
      '103.58',
      '27.60',
      '59.90',
    ];
    final prefix = prefixes[random.nextInt(prefixes.length)];
    final c = 1 + random.nextInt(252);
    final d = 1 + random.nextInt(252);
    return '$prefix.$c.$d';
  }

  static String _randomHex(int length) {
    final random = Random.secure();
    const alphabet = '0123456789abcdef';
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  static String _randomUuid() {
    final random = Random.secure();
    const alphabet = '0123456789abcdef';
    String chunk(int size) => List.generate(
      size,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return '${chunk(8)}-${chunk(4)}-${chunk(4)}-${chunk(4)}-${chunk(12)}';
  }
}
