import 'dart:developer' as developer;

/// Minimal logging façade used across the app.
///
/// Log output never contains credentials, cookies or signed URLs: URLs are
/// reduced to scheme + host, exactly like the reference implementation.
abstract final class AppLogger {
  static void info(String message, {String? tag}) {
    developer.log(_sanitize(message), name: tag ?? 'snigea', level: 900);
  }

  static void warn(String message, {String? tag}) {
    developer.log(_sanitize(message), name: tag ?? 'snigea', level: 1000);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      _sanitize(message),
      name: 'snigea',
      level: 2000,
      error: error == null ? null : _sanitize(error.toString()),
      stackTrace: stackTrace,
    );
  }

  /// Reduces a URL to `scheme://host[:port]`, dropping path and query.
  static String sanitizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '[redacted]';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$port';
    }
    final schemeIndex = trimmed.indexOf('://');
    if (schemeIndex < 0) return '[redacted]';
    final scheme = trimmed.substring(0, schemeIndex);
    var rest = trimmed.substring(schemeIndex + 3);
    final hostEnd = rest.indexOf(RegExp(r'[/?#]'));
    var host = hostEnd < 0 ? rest : rest.substring(0, hostEnd);
    final atIndex = host.lastIndexOf('@');
    if (atIndex >= 0) host = host.substring(atIndex + 1);
    if (host.isEmpty) return '[redacted]';
    return '$scheme://$host';
  }

  static String _sanitize(String message) {
    return message.replaceAllMapped(
      RegExp("https?://[^\\s\"'<>]+"),
      (match) => sanitizeUrl(match.group(0)!),
    );
  }
}
