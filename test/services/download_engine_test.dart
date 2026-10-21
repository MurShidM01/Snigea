import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/platform/file_store.dart';
import 'package:snigea/services/download_engine.dart';

/// A file store that keeps everything in a temporary directory.
class _TempFileStore implements FileStore {
  _TempFileStore(this.root);

  final Directory root;

  @override
  bool get isSupported => true;

  @override
  String? get unsupportedReason => null;

  @override
  Future<String> downloadsDirectory() async => root.path;

  @override
  Future<ManagedFile> createFile(
    String relativePath, {
    int? preallocate,
    bool append = false,
  }) async {
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    final handle = await file.open(
      mode: append ? FileMode.append : FileMode.write,
    );
    if (!append && preallocate != null && preallocate > 0) {
      handle.truncateSync(preallocate);
    }
    return _TempFile(handle);
  }

  @override
  Future<bool> exists(String relativePath) async =>
      File('${root.path}/$relativePath').existsSync();

  @override
  Future<int> lengthOf(String relativePath) async {
    final file = File('${root.path}/$relativePath');
    if (!file.existsSync()) return 0;
    return file.lengthSync();
  }

  @override
  Future<void> delete(String relativePath) async {
    final file = File('${root.path}/$relativePath');
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<void> rename(String from, String to) async {
    final source = File('${root.path}/$from');
    if (!source.existsSync()) return;
    final target = File('${root.path}/$to');
    await target.parent.create(recursive: true);
    await source.rename(target.path);
  }

  @override
  Future<String> readString(String relativePath) async {
    final file = File('${root.path}/$relativePath');
    if (!file.existsSync()) return '';
    return file.readAsString();
  }

  @override
  Future<void> writeString(String relativePath, String content) async {
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  @override
  Future<List<String>> list(String relativePath) async {
    final directory = Directory('${root.path}/$relativePath');
    if (!directory.existsSync()) return const [];
    return directory
        .listSync()
        .whereType<File>()
        .map((file) => file.path.split('/').last)
        .toList();
  }

  @override
  Future<String> absolutePath(String relativePath) async =>
      '${root.path}/$relativePath';
}

class _TempFile implements ManagedFile {
  _TempFile(this._file);

  final RandomAccessFile _file;

  @override
  Future<void> append(List<int> bytes) async {
    await _file.writeFrom(bytes);
  }

  @override
  Future<void> writeAt(int position, List<int> bytes) async {
    _file.setPositionSync(position);
    await _file.writeFrom(bytes);
  }

  @override
  Future<int> length() async => _file.lengthSync();

  @override
  Future<void> flush() async {
    _file.flushSync();
  }

  @override
  Future<void> close() async {
    _file.closeSync();
  }
}

void main() {
  late HttpServer server;
  late List<int> payload;
  late Directory directory;
  late _TempFileStore store;

  setUp(() async {
    final random = Random(42);
    payload = List<int>.generate(64 * 1024, (_) => random.nextInt(256));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      var start = 0;
      var end = payload.length - 1;
      var partial = false;
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final spec = rangeHeader.substring(6).split('-');
        start = int.tryParse(spec.first) ?? 0;
        if (spec.length > 1 && spec[1].isNotEmpty) {
          end = int.tryParse(spec[1]) ?? end;
        }
        partial = true;
      }
      if (start >= payload.length) {
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          'content-range',
          'bytes */${payload.length}',
        );
        await request.response.close();
        return;
      }
      final chunk = payload.sublist(start, end + 1);
      if (partial) {
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          'content-range',
          'bytes $start-$end/${payload.length}',
        );
      }
      request.response.headers.contentLength = chunk.length;
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.add(chunk);
      await request.response.close();
    });

    directory = await Directory.systemTemp.createTemp('snigea_download_test');
    store = _TempFileStore(directory);
  });

  tearDown(() async {
    await server.close(force: true);
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('downloads a file and reports the progress', () async {
    final engine = DownloadEngine(store: store);
    final progress = <DownloadProgress>[];

    final result = await engine.download(
      DownloadRequest(
        url: 'http://127.0.0.1:${server.port}/movie.mp4',
        relativePath: 'Downloads/movie.mp4',
        fileName: 'movie.mp4',
      ),
      onProgress: progress.add,
    );

    expect(result.outcome, DownloadOutcome.completed);
    expect(result.bytes, payload.length);
    expect(await store.lengthOf('Downloads/movie.mp4'), payload.length);
    expect(await store.exists('Downloads/movie.mp4.part'), isFalse);
    expect(await store.exists('Downloads/movie.mp4.part.json'), isFalse);
    expect(progress, isNotEmpty);
    expect(progress.last.downloaded, payload.length);
  });

  test('resumes a partially downloaded file', () async {
    final engine = DownloadEngine(store: store);

    // Simulate an interrupted download: half of the file plus the metadata.
    final partial = File('${directory.path}/Downloads/movie.mp4.part');
    await partial.parent.create(recursive: true);
    await store.writeString(
      'Downloads/movie.mp4.part.json',
      '{"etag":null,"last_modified":null,"total":${payload.length},'
          '"segments":null,"segment_progress":[]}',
    );
    await partial.writeAsBytes(payload.sublist(0, payload.length ~/ 2));

    final result = await engine.download(
      DownloadRequest(
        url: 'http://127.0.0.1:${server.port}/movie.mp4',
        relativePath: 'Downloads/movie.mp4',
        fileName: 'movie.mp4',
      ),
    );

    expect(result.outcome, DownloadOutcome.completed);
    expect(await store.lengthOf('Downloads/movie.mp4'), payload.length);
    final written = File('${directory.path}/Downloads/movie.mp4')
        .readAsBytesSync();
    expect(written, payload);
  });

  test('keeps the partial file when the download is cancelled', () async {
    final engine = DownloadEngine(store: store);

    final result = await engine.download(
      DownloadRequest(
        url: 'http://127.0.0.1:${server.port}/movie.mp4',
        relativePath: 'Downloads/movie.mp4',
        fileName: 'movie.mp4',
      ),
      isCancelled: () => true,
    );

    expect(result.outcome, DownloadOutcome.cancelled);
    expect(await store.exists('Downloads/movie.mp4'), isFalse);
  });

  test(
    'reports the progress while a large file is downloaded in segments',
    () async {
      // A file above the segment threshold is downloaded with parallel range
      // requests. The progress has to be reported while the segments run, not
      // only at the very end.
      final large = List<int>.generate(9 * 1024 * 1024, (index) => index % 251);
      payload = large;

      final engine = DownloadEngine(store: store);
      final progress = <DownloadProgress>[];

      final result = await engine.download(
        DownloadRequest(
          url: 'http://127.0.0.1:${server.port}/movie.mkv',
          relativePath: 'Downloads/movie.mkv',
          fileName: 'movie.mkv',
        ),
        onProgress: progress.add,
      );

      expect(result.outcome, DownloadOutcome.completed);
      expect(progress.length, greaterThan(1));
      expect(progress.first.downloaded, lessThan(result.bytes));
      expect(progress.last.downloaded, result.bytes);
      expect(await store.lengthOf('Downloads/movie.mkv'), large.length);

      // The parallel segments must not corrupt the file.
      final written = File('${directory.path}/Downloads/movie.mkv')
          .readAsBytesSync();
      expect(written.length, large.length);
      expect(written, large);
    },
  );

  test(
    'falls back to a single request when the server ignores the ranges',
    () async {
      // A server that always answers with the whole file breaks the parallel
      // segments. The engine has to fall back to a sequential download.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentLength = payload.length;
        request.response.add(payload);
        await request.response.close();
      });

      payload = List<int>.generate(9 * 1024 * 1024, (index) => index % 251);

      final engine = DownloadEngine(store: store);
      final result = await engine.download(
        DownloadRequest(
          url: 'http://127.0.0.1:${server.port}/movie.mkv',
          relativePath: 'Downloads/movie.mkv',
          fileName: 'movie.mkv',
        ),
      );

      expect(result.outcome, DownloadOutcome.completed);
      expect(await store.lengthOf('Downloads/movie.mkv'), payload.length);
    },
  );

  test('reports a failure when the server is unreachable', () async {
    final engine = DownloadEngine(store: store);
    final port = server.port;
    await server.close(force: true);

    final result = await engine.download(
      DownloadRequest(
        url: 'http://127.0.0.1:$port/movie.mp4',
        relativePath: 'Downloads/movie.mp4',
        fileName: 'movie.mp4',
      ),
    );

    expect(result.outcome, DownloadOutcome.failed);
    expect(result.error, isNotNull);
  });
}
