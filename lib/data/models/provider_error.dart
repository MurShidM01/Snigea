import 'provider_kind.dart';

/// Errors surfaced by the provider layer.
sealed class ProviderError implements Exception {
  const ProviderError();

  /// A short, user facing description of the failure.
  String userMessage(ProviderKind provider);

  /// The technical detail, safe to show in a diagnostics panel.
  String get detail;

  @override
  String toString() => '$runtimeType: $detail';
}

/// The provider could not be reached.
class NetworkError extends ProviderError {
  const NetworkError(this.detail);

  @override
  final String detail;

  @override
  String userMessage(ProviderKind provider) {
    if (provider.isBdix) {
      return '$provider unreachable: requires a BDIX network.';
    }
    final lower = detail.toLowerCase();
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return '$provider timed out.';
    }
    return 'Cannot reach $provider.';
  }
}

/// The provider asked us to slow down.
class RateLimitedError extends ProviderError {
  const RateLimitedError([this.retryAfterSeconds]);

  final int? retryAfterSeconds;

  @override
  String get detail =>
      'Rate limited${retryAfterSeconds == null ? '' : ', retry after ${retryAfterSeconds}s'}';

  @override
  String userMessage(ProviderKind provider) {
    final seconds = retryAfterSeconds;
    return seconds == null
        ? 'Rate limited. Try again later.'
        : 'Rate limited. Wait ${seconds}s.';
  }
}

/// The requested item does not exist.
class NotFoundError extends ProviderError {
  const NotFoundError([this.detail = 'not found']);

  @override
  final String detail;

  @override
  String userMessage(ProviderKind provider) => 'No results found.';
}

/// The response could not be understood.
class ParsingError extends ProviderError {
  const ParsingError(this.detail);

  @override
  final String detail;

  @override
  String userMessage(ProviderKind provider) => '$provider parse error.';
}

/// The provider answered, but with an error status.
class ProviderUnavailableError extends ProviderError {
  const ProviderUnavailableError(this.detail);

  @override
  final String detail;

  @override
  String userMessage(ProviderKind provider) {
    final trimmed = detail.trim();
    if (trimmed.startsWith('HTTP status ')) {
      return '$provider error (${trimmed.substring('HTTP status '.length)}).';
    }
    if (trimmed.isEmpty) return '$provider unavailable.';
    return '$provider unavailable: $trimmed';
  }
}
