import 'dart:async';

import 'package:dio/dio.dart';

import 'user_agents.dart';

/// Default request tuning shared by every provider.
abstract final class HttpDefaults {
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  /// Maximum number of attempts (including the first one).
  static const int maxAttempts = 3;

  /// Base delay for the exponential backoff between attempts.
  static const Duration backoffBase = Duration(milliseconds: 400);
}

/// A tiny counting semaphore used to bound global request concurrency.
class ConcurrencyLimiter {
  ConcurrencyLimiter(this.maxConcurrent);

  final int maxConcurrent;
  int _active = 0;
  final List<Completer<void>> _waiting = [];

  /// Runs [action] once a slot is available.
  Future<T> run<T>(Future<T> Function() action) async {
    if (_active >= maxConcurrent) {
      final completer = Completer<void>();
      _waiting.add(completer);
      await completer.future;
    }
    _active++;
    try {
      return await action();
    } finally {
      _active--;
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      }
    }
  }
}

/// Creates configured [Dio] instances.
///
/// The client centralises timeouts, the shared user agent and the retry
/// policy so that individual providers stay small.
abstract final class HttpClientFactory {
  static Dio create({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    String? userAgent,
    bool followRedirects = true,
    int maxRedirects = 5,
  }) {
    return Dio(
      BaseOptions(
        connectTimeout: connectTimeout ?? HttpDefaults.connectTimeout,
        receiveTimeout: receiveTimeout ?? HttpDefaults.receiveTimeout,
        sendTimeout: HttpDefaults.sendTimeout,
        followRedirects: followRedirects,
        maxRedirects: maxRedirects,
        headers: {
          'User-Agent': userAgent ?? UserAgents.browser,
          'Accept': '*/*',
        },
        // Any status is returned to the caller so that domain errors can be
        // mapped onto meaningful messages.
        validateStatus: (status) => status != null && status < 600,
      ),
    );
  }

  /// Whether a failed request may be retried.
  static bool isRetryable(DioException error) {
    final status = error.response?.statusCode;
    if (status == null) return true;
    return status == 408 ||
        status == 425 ||
        status == 429 ||
        (status >= 500 && status < 600);
  }

  /// The delay before the next attempt.
  static Duration retryDelay(int attempt, DioException? error) {
    final retryAfter = error?.response?.headers.value('retry-after');
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter.trim());
      if (seconds != null) {
        return Duration(seconds: seconds.clamp(1, 30));
      }
    }
    return HttpDefaults.backoffBase * (1 << (attempt - 1));
  }
}
