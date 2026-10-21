// The constructors below use public named parameters that are assigned to
// private fields. Dart does not allow private named parameters, therefore the
// `prefer_initializing_formals` hint does not apply here.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/logging/app_logger.dart';
import '../core/network/http_client_factory.dart';
import '../core/platform/file_store.dart';

/// The progress of a running download.
class DownloadProgress {
  const DownloadProgress({
    required this.downloaded,
    required this.attempt,
    required this.workers,
    this.total,
    this.bytesPerSecond = 0,
  });

  final int downloaded;
  final int? total;
  final double bytesPerSecond;
  final int attempt;
  final int workers;

  /// The progress in percent, or `null` when the total size is unknown.
  double? get fraction {
    final size = total;
    if (size == null || size <= 0) return null;
    return (downloaded / size).clamp(0.0, 1.0);
  }
}

/// The outcome of a download.
enum DownloadOutcome { completed, paused, cancelled, failed }

/// The result of a finished download.
class DownloadResult {
  const DownloadResult({
    required this.outcome,
    required this.bytes,
    this.error,
    this.integrity,
  });

  final DownloadOutcome outcome;
  final int bytes;
  final String? error;
  final String? integrity;
}

/// A download request.
class DownloadRequest {
  const DownloadRequest({
    required this.url,
    required this.relativePath,
    this.headers = const [],
    this.fileName = 'download',
  });

  final String url;
  final String relativePath;
  final List<MapEntry<String, String>> headers;
  final String fileName;
}

/// The resume metadata that is stored next to a partial download.
class _ResumeMetadata {
  const _ResumeMetadata({
    this.etag,
    this.lastModified,
    this.total,
    this.segments,
    this.segmentProgress = const [],
  });

  final String? etag;
  final String? lastModified;
  final int? total;
  final int? segments;
  final List<int> segmentProgress;

  Map<String, Object?> toJson() => {
    'etag': etag,
    'last_modified': lastModified,
    'total': total,
    'segments': segments,
    'segment_progress': segmentProgress,
  };

  static _ResumeMetadata fromJson(Map<String, Object?> json) => _ResumeMetadata(
    etag: json['etag'] as String?,
    lastModified: json['last_modified'] as String?,
    total: (json['total'] as num?)?.toInt(),
    segments: (json['segments'] as num?)?.toInt(),
    segmentProgress: (json['segment_progress'] as List? ?? const [])
        .map((entry) => (entry as num).toInt())
        .toList(),
  );
}

/// The HTTP range downloader.
///
/// The engine mirrors the reference implementation: a partial file plus a
/// resume metadata file allow a paused or failed download to continue, and
/// large files are fetched with several parallel range requests.
class DownloadEngine {
  DownloadEngine({required FileStore store, Dio? dio})
    : _store = store,
      _dio =
          dio ??
          HttpClientFactory.create(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 60),
          );

  /// The maximum number of attempts.
  static const int maxAttempts = 4;

  /// Files below this size are downloaded in a single request.
  static const int segmentThreshold = 8 * 1024 * 1024;

  /// The maximum number of parallel segments.
  static const int maxSegments = 16;

  final FileStore _store;
  final Dio _dio;

  /// The last time a segmented download reported its progress.
  DateTime _lastSegmentReport = DateTime.fromMillisecondsSinceEpoch(0);

  /// Downloads [request] and reports the progress through [onProgress].
  ///
  /// The [isCancelled] callback is polled between chunks so that a download
  /// can be stopped cooperatively.
  Future<DownloadResult> download(
    DownloadRequest request, {
    void Function(DownloadProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!_store.isSupported) {
      return DownloadResult(
        outcome: DownloadOutcome.failed,
        bytes: 0,
        error: _store.unsupportedReason,
      );
    }

    final partialPath = '${request.relativePath}.part';
    final metadataPath = '${request.relativePath}.part.json';

    var attempt = 0;
    while (attempt < maxAttempts) {
      attempt++;
      if (isCancelled?.call() ?? false) {
        return DownloadResult(
          outcome: DownloadOutcome.cancelled,
          bytes: await _store.lengthOf(partialPath),
        );
      }

      try {
        final outcome = await _attempt(
          request,
          partialPath: partialPath,
          metadataPath: metadataPath,
          attempt: attempt,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        if (outcome != null) return outcome;
      } on DioException catch (error) {
        AppLogger.warn('download attempt $attempt failed: ${error.type}');
        if (attempt >= maxAttempts) {
          return DownloadResult(
            outcome: DownloadOutcome.failed,
            bytes: await _store.lengthOf(partialPath),
            error: _describe(error),
          );
        }
        await Future<void>.delayed(
          HttpDefaults.backoffBase * (1 << (attempt - 1)),
        );
      }
    }

    return DownloadResult(
      outcome: DownloadOutcome.failed,
      bytes: await _store.lengthOf(partialPath),
      error: 'The download could not be completed.',
    );
  }

  Future<DownloadResult?> _attempt(
    DownloadRequest request, {
    required String partialPath,
    required String metadataPath,
    required int attempt,
    void Function(DownloadProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final metadata = await _readMetadata(metadataPath);
    final existing = await _store.lengthOf(partialPath);

    var offset = existing;
    if (metadata.segments != null) {
      // The partial file is pre-allocated; restart from the segment state.
      offset = metadata.segmentProgress.fold<int>(0, (a, b) => a + b);
    }

    final headers = <String, String>{
      for (final header in request.headers) header.key: header.value,
    };
    final ifRange = metadata.etag ?? metadata.lastModified;
    if (offset > 0) {
      headers['Range'] = 'bytes=$offset-';
      if (ifRange != null) headers['If-Range'] = ifRange;
    }

    var response = await _request(request.url, headers);

    var status = response.statusCode ?? 0;
    if (status == 416 && metadata.total == offset && offset > 0) {
      await _finalize(partialPath, metadataPath, request.relativePath);
      return DownloadResult(outcome: DownloadOutcome.completed, bytes: offset);
    }
    if (status < 200 || status >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'HTTP status $status',
      );
    }

    var contentLength = int.tryParse(
      response.headers.value('content-length') ?? '',
    );
    var contentRange = response.headers.value('content-range');
    var total =
        _totalFromContentRange(contentRange) ??
        (status == 200 ? contentLength : metadata.total);

    final supportsRanges = response.headers.value('accept-ranges') != 'none';

    if (status == 206 && contentRange != null) {
      final start = _startFromContentRange(contentRange);
      if (start != null && start != offset) {
        await _store.delete(partialPath);
        await _store.delete(metadataPath);
        throw DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.badResponse,
          error: 'Requested byte $offset, received $start',
        );
      }
    } else if (status == 200 && offset > 0) {
      // The server ignored the range request; restart from scratch.
      await _store.delete(partialPath);
      await _store.delete(metadataPath);
      offset = 0;
    }

    final etag = response.headers.value('etag');
    final lastModified = response.headers.value('last-modified');

    final canSegment =
        offset == 0 &&
        total != null &&
        total >= segmentThreshold &&
        supportsRanges &&
        (status == 200 || status == 206);

    if (canSegment) {
      final expectedTotal = total;
      final segments = _segmentCount(expectedTotal);
      final segmentProgress = List<int>.filled(segments, 0);
      await _store.createFile(partialPath, preallocate: expectedTotal);
      await _writeMetadata(
        metadataPath,
        _ResumeMetadata(
          etag: etag,
          lastModified: lastModified,
          total: expectedTotal,
          segments: segments,
          segmentProgress: segmentProgress,
        ),
      );
      try {
        final result = await _downloadSegmented(
          request,
          partialPath: partialPath,
          metadataPath: metadataPath,
          total: expectedTotal,
          segments: segments,
          segmentProgress: segmentProgress,
          attempt: attempt,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        if (result != null) return result;
      } on DioException catch (error) {
        // The server does not serve the requested ranges after all, so the
        // file is fetched with a single request instead.
        AppLogger.warn('the segmented download failed: $error');
      }
      // Fall back to a sequential download with a fresh request.
      await _store.delete(partialPath);
      await _store.delete(metadataPath);
      offset = 0;
      final fallbackHeaders = <String, String>{
        for (final header in request.headers) header.key: header.value,
      };
      response = await _request(request.url, fallbackHeaders);
      status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'HTTP status $status',
        );
      }
      contentLength = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      contentRange = response.headers.value('content-range');
      total =
          _totalFromContentRange(contentRange) ??
          (status == 200 ? contentLength : null);
    }

    // Sequential download.
    await _writeMetadata(
      metadataPath,
      _ResumeMetadata(etag: etag, lastModified: lastModified, total: total),
    );

    // Resuming keeps the bytes that were downloaded before.
    final file = await _store.createFile(partialPath, append: offset > 0);
    var downloaded = offset;
    final started = DateTime.now();
    var lastReport = DateTime.now();

    try {
      await for (final chunk in response.data!.stream) {
        if (isCancelled?.call() ?? false) {
          await file.flush();
          await file.close();
          return DownloadResult(
            outcome: DownloadOutcome.cancelled,
            bytes: downloaded,
          );
        }
        await file.append(chunk);
        downloaded += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastReport) >= const Duration(milliseconds: 200)) {
          lastReport = now;
          final elapsed = now.difference(started).inMilliseconds;
          onProgress?.call(
            DownloadProgress(
              downloaded: downloaded,
              total: total,
              bytesPerSecond: elapsed <= 0
                  ? 0
                  : (downloaded - offset) / elapsed * 1000,
              attempt: attempt,
              workers: 1,
            ),
          );
        }
      }
      await file.flush();
      await file.close();
    } on DioException {
      await file.close();
      rethrow;
    }

    if (total != null && downloaded != total) {
      throw DioException(
        requestOptions: response.requestOptions,
        type: DioExceptionType.badResponse,
        error: 'Incomplete download: $downloaded of $total bytes',
      );
    }

    onProgress?.call(
      DownloadProgress(
        downloaded: downloaded,
        total: total,
        attempt: attempt,
        workers: 1,
      ),
    );

    final integrity = await _finalize(
      partialPath,
      metadataPath,
      request.relativePath,
    );
    return DownloadResult(
      outcome: DownloadOutcome.completed,
      bytes: downloaded,
      integrity: integrity,
    );
  }

  Future<DownloadResult?> _downloadSegmented(
    DownloadRequest request, {
    required String partialPath,
    required String metadataPath,
    required int total,
    required int segments,
    required List<int> segmentProgress,
    required int attempt,
    void Function(DownloadProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final ranges = _segmentRanges(total, segments);
    // The file is allocated first. The workers share a single handle, so
    // every write is serialised through a lock: a file handle has one
    // shared position and concurrent writes would corrupt the file.
    final file = await _store.createFile(partialPath, preallocate: total);
    final lock = _AsyncLock();

    var cancelled = false;
    final started = DateTime.now();

    Future<void> worker(int index) async {
      final range = ranges[index];
      final already = segmentProgress[index];
      if (already >= range.length) return;
      final start = range.start + already;
      final headers = <String, String>{
        for (final header in request.headers) header.key: header.value,
        'Range': 'bytes=$start-${range.end}',
      };
      final response = await _dio.get<ResponseBody>(
        request.url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status != 206) {
        throw DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.badResponse,
          error: 'Expected HTTP 206, received $status',
        );
      }

      var written = 0;
      await for (final chunk in response.data!.stream) {
        if (isCancelled?.call() ?? false) {
          cancelled = true;
          break;
        }
        await lock.run(() => file.writeAt(start + written, chunk));
        written += chunk.length;
        segmentProgress[index] = already + written;
        _reportSegmentProgress(
          segmentProgress,
          total: total,
          attempt: attempt,
          workers: segments,
          started: started,
          onProgress: onProgress,
        );
      }
    }

    try {
      await Future.wait([
        for (var index = 0; index < segments; index++) worker(index),
      ]);
    } catch (_) {
      await file.flush();
      await file.close();
      rethrow;
    }

    await file.flush();
    await file.close();

    if (cancelled) {
      return DownloadResult(
        outcome: DownloadOutcome.cancelled,
        bytes: segmentProgress.fold<int>(0, (a, b) => a + b),
      );
    }

    final downloaded = segmentProgress.fold<int>(0, (a, b) => a + b);
    if (downloaded != total) {
      throw DioException(
        requestOptions: RequestOptions(path: request.url),
        type: DioExceptionType.badResponse,
        error: 'Incomplete download: $downloaded of $total bytes',
      );
    }

    onProgress?.call(
      DownloadProgress(
        downloaded: downloaded,
        total: total,
        attempt: attempt,
        workers: segments,
      ),
    );

    final integrity = await _finalize(
      partialPath,
      metadataPath,
      request.relativePath,
    );
    return DownloadResult(
      outcome: DownloadOutcome.completed,
      bytes: downloaded,
      integrity: integrity,
    );
  }

  /// Performs the ranged request of the transfer.
  Future<Response<ResponseBody>> _request(
    String url,
    Map<String, String> headers,
  ) {
    return _dio.get<ResponseBody>(
      url,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
  }

  /// Reports the aggregated progress of the parallel segments.
  ///
  /// The report is throttled, so a fast download does not flood the user
  /// interface with updates.
  void _reportSegmentProgress(
    List<int> segmentProgress, {
    required int total,
    required int attempt,
    required int workers,
    required DateTime started,
    void Function(DownloadProgress progress)? onProgress,
  }) {
    if (onProgress == null) return;
    final now = DateTime.now();
    if (now.difference(_lastSegmentReport) <
        const Duration(milliseconds: 200)) {
      return;
    }
    _lastSegmentReport = now;
    final downloaded = segmentProgress.fold<int>(0, (a, b) => a + b);
    final elapsed = now.difference(started).inMilliseconds;
    onProgress(
      DownloadProgress(
        downloaded: downloaded,
        total: total,
        bytesPerSecond: elapsed <= 0 ? 0 : downloaded / elapsed * 1000,
        attempt: attempt,
        workers: workers,
      ),
    );
  }

  Future<String?> _finalize(
    String partialPath,
    String metadataPath,
    String targetPath,
  ) async {
    final size = await _store.lengthOf(partialPath);
    await _store.rename(partialPath, targetPath);
    await _store.delete(metadataPath);
    return 'size:$size';
  }

  Future<_ResumeMetadata> _readMetadata(String path) async {
    final raw = await _store.readString(path);
    if (raw.isEmpty) return const _ResumeMetadata();
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return _ResumeMetadata.fromJson(json.cast<String, Object?>());
      }
    } on FormatException {
      // A corrupt resume file simply restarts the download.
    }
    return const _ResumeMetadata();
  }

  Future<void> _writeMetadata(String path, _ResumeMetadata metadata) =>
      _store.writeString(path, jsonEncode(metadata.toJson()));

  static int _segmentCount(int total) {
    if (total < 32 * 1024 * 1024) return 4;
    if (total < 128 * 1024 * 1024) return 8;
    if (total < 512 * 1024 * 1024) return 12;
    return maxSegments;
  }

  static List<_ByteRange> _segmentRanges(int total, int segments) {
    final size = total ~/ segments;
    final ranges = <_ByteRange>[];
    for (var index = 0; index < segments; index++) {
      final start = index * size;
      final end = index == segments - 1 ? total - 1 : start + size - 1;
      ranges.add(_ByteRange(start, end));
    }
    return ranges;
  }

  static int? _totalFromContentRange(String? contentRange) {
    if (contentRange == null) return null;
    final parts = contentRange.split('/');
    if (parts.length < 2) return null;
    final total = int.tryParse(parts.last.trim());
    return total;
  }

  static int? _startFromContentRange(String contentRange) {
    final parts = contentRange.split(' ');
    if (parts.length < 2) return null;
    final range = parts[1].split('-');
    if (range.isEmpty) return null;
    return int.tryParse(range.first);
  }

  static String _describe(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'The server refused the download (HTTP $status).';
    }
    if (status == 404 || status == 410) {
      return 'The file is no longer available on the server.';
    }
    if (status == 429) {
      return 'The server rate limited the download. Try again later.';
    }
    if (status != null && status >= 500) {
      return 'The server reported an error (HTTP $status).';
    }
    return error.message ?? 'The download failed.';
  }
}

/// A tiny asynchronous lock.
///
/// The parallel download workers share a single file handle, therefore the
/// writes have to be serialised.
class _AsyncLock {
  Future<void> _tail = Future<void>.value();

  /// Runs [action] once the lock is free.
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _tail;
    _tail = completer.future.then<void>((_) {}, onError: (Object _) {});
    previous.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

class _ByteRange {
  const _ByteRange(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start + 1;
}
