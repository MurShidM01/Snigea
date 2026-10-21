// The constructors below use public named parameters that are assigned to
// private fields. Dart does not allow private named parameters, therefore the
// `prefer_initializing_formals` hint does not apply here.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../core/logging/app_logger.dart';
import '../core/platform/file_store.dart';
import '../core/text/cleaners.dart';
import '../data/models/media.dart';
import '../data/models/release.dart';
import 'playback_service.dart';
import '../data/repositories/download_repository.dart';
import 'download_engine.dart';

/// The runtime state of a download.
class DownloadState {
  const DownloadState({
    required this.task,
    this.progress = 0,
    this.bytesPerSecond = 0,
    this.error,
  });

  final DownloadTask task;
  final double progress;
  final double bytesPerSecond;
  final String? error;

  DownloadState copyWith({
    DownloadTask? task,
    double? progress,
    double? bytesPerSecond,
    String? error,
  }) => DownloadState(
    task: task ?? this.task,
    progress: progress ?? this.progress,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    error: error,
  );
}

/// Orchestrates the download tasks.
///
/// The service keeps the persistent records in the database up to date and
/// exposes the live progress to the user interface.
class DownloadService {
  DownloadService({
    required DownloadRepository repository,
    required FileStore fileStore,
    required DownloadEngine engine,
    required PlaybackService playbackService,
  }) : _repository = repository,
       _fileStore = fileStore,
       _engine = engine,
       _playbackService = playbackService;

  final DownloadRepository _repository;
  final FileStore _fileStore;
  final DownloadEngine _engine;
  final PlaybackService _playbackService;

  final Map<int, bool> _cancelled = {};
  final Map<int, StreamController<DownloadState>> _controllers = {};
  final Map<int, DownloadState> _states = {};
  final Map<int, int> _lastPersisted = {};
  final StreamController<DownloadState> _globalController =
      StreamController<DownloadState>.broadcast();

  /// Whether the platform supports downloads.
  bool get isSupported => _fileStore.isSupported;

  /// The reason why downloads are unavailable, if they are.
  String? get unsupportedReason => _fileStore.unsupportedReason;

  /// The live state of a download.
  DownloadState? stateOf(int taskId) => _states[taskId];

  /// Every state change of every download.
  Stream<DownloadState> get states => _globalController.stream;

  /// Watches the live state of a download.
  Stream<DownloadState> watch(int taskId) {
    final existing = _controllers[taskId];
    if (existing != null) return existing.stream;
    final controller = StreamController<DownloadState>.broadcast();
    _controllers[taskId] = controller;
    final current = _states[taskId];
    if (current != null) controller.add(current);
    return controller.stream;
  }

  /// Queues a release for download.
  Future<DownloadTask?> enqueue({
    required Release release,
    required MediaDetails details,
    int season = 0,
    int episode = 0,
  }) async {
    if (!isSupported) return null;
    if (release.mirrors.isEmpty) return null;

    // The listed mirror is not always the media file: 4KHDHub publishes a
    // resolver page and the MovieBox links expire. The source is therefore
    // resolved before the transfer starts.
    PlaybackSource? source;
    try {
      source = await _playbackService.resolve(
        release,
        intent: ResolutionIntent.download,
        subjectId: details.id.value,
      );
    } catch (error) {
      AppLogger.warn('the download source could not be resolved: $error');
    }
    final mirror = release.mirrors.first;
    final url = source?.url ?? mirror.resolverUrl;
    final headers = source?.headers.isNotEmpty == true
        ? source!.headers
        : mirror.headers;

    final fileName = _buildFileName(
      release: release,
      details: details,
      season: season,
      episode: episode,
    );

    final task = DownloadTask(
      provider: details.id.provider,
      subjectId: details.id.value,
      title: details.title,
      season: season,
      episode: episode,
      url: url,
      headers: headers,
      fileName: fileName,
      posterUrl: details.posterUrl,
      status: DownloadStatus.queued,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final id = await _repository.insert(task);
    final stored = DownloadTask(
      id: id,
      provider: task.provider,
      subjectId: task.subjectId,
      title: task.title,
      season: task.season,
      episode: task.episode,
      url: task.url,
      headers: task.headers,
      fileName: task.fileName,
      posterUrl: task.posterUrl,
      status: DownloadStatus.queued,
      createdAt: task.createdAt,
    );
    _emit(stored);

    unawaited(_run(stored));
    return stored;
  }

  /// Resumes a paused or failed download.
  Future<void> resume(DownloadTask task) async {
    if (task.id == null) return;
    _cancelled.remove(task.id);
    final updated = DownloadTask(
      id: task.id,
      provider: task.provider,
      subjectId: task.subjectId,
      title: task.title,
      season: task.season,
      episode: task.episode,
      url: task.url,
      headers: task.headers,
      fileName: task.fileName,
      posterUrl: task.posterUrl,
      filePath: task.filePath,
      totalBytes: task.totalBytes,
      downloadedBytes: task.downloadedBytes,
      status: DownloadStatus.queued,
      createdAt: task.createdAt,
    );
    await _repository.update(updated);
    _emit(updated);
    unawaited(_run(updated));
  }

  /// Pauses a running download.
  ///
  /// The partial file is kept, so the download continues where it stopped
  /// when it is resumed.
  Future<void> pause(DownloadTask task) async {
    final id = task.id;
    if (id == null) return;
    _cancelled[id] = true;
  }

  /// The progress of a running download is written to the database as well,
  /// so the list stays accurate after a restart.
  Future<void> _persistProgress(int id, DownloadState state) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastPersisted[id] ?? 0) <
        const Duration(seconds: 2).inMilliseconds) {
      return;
    }
    _lastPersisted[id] = now;
    await _repository.update(
      DownloadTask(
        id: id,
        provider: state.task.provider,
        subjectId: state.task.subjectId,
        title: state.task.title,
        season: state.task.season,
        episode: state.task.episode,
        url: state.task.url,
        headers: state.task.headers,
        fileName: state.task.fileName,
        posterUrl: state.task.posterUrl,
        filePath: state.task.filePath,
        totalBytes: state.task.totalBytes,
        downloadedBytes: (state.progress * (state.task.totalBytes ?? 0))
            .round(),
        status: DownloadStatus.running,
        createdAt: state.task.createdAt,
      ),
    );
  }

  /// Cancels a download and removes its files.
  Future<void> remove(DownloadTask task) async {
    final id = task.id;
    if (id == null) return;
    _cancelled[id] = true;
    await _repository.remove(id);
    await _fileStore.delete('Downloads/${task.fileName}');
    await _fileStore.delete('Downloads/${task.fileName}.part');
    await _fileStore.delete('Downloads/${task.fileName}.part.json');
    _states.remove(id);
    _controllers.remove(id)?.close();
  }

  /// Removes the leftover partial files of finished tasks.
  Future<int> cleanupPartials() async {
    final files = await _fileStore.list('Downloads');
    var removed = 0;
    for (final file in files) {
      if (file.endsWith('.part') || file.endsWith('.part.json')) {
        await _fileStore.delete('Downloads/$file');
        removed++;
      }
    }
    return removed;
  }

  Future<void> _run(DownloadTask task) async {
    final id = task.id;
    if (id == null) return;
    try {
      await _runTransfer(task);
    } catch (error, stackTrace) {
      AppLogger.error(
        'the download failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      final failed = DownloadTask(
        id: id,
        provider: task.provider,
        subjectId: task.subjectId,
        title: task.title,
        season: task.season,
        episode: task.episode,
        url: task.url,
        headers: task.headers,
        fileName: task.fileName,
        posterUrl: task.posterUrl,
        status: DownloadStatus.failed,
        error: '$error',
        createdAt: task.createdAt,
      );
      await _repository.update(failed);
      _emit(failed);
    }
  }

  Future<void> _runTransfer(DownloadTask task) async {
    final id = task.id;
    if (id == null) return;

    var current = DownloadTask(
      id: id,
      provider: task.provider,
      subjectId: task.subjectId,
      title: task.title,
      season: task.season,
      episode: task.episode,
      url: task.url,
      headers: task.headers,
      fileName: task.fileName,
      posterUrl: task.posterUrl,
      status: DownloadStatus.running,
      createdAt: task.createdAt,
    );
    await _repository.update(current);
    _emit(current);

    final result = await _engine.download(
      DownloadRequest(
        url: task.url,
        relativePath: 'Downloads/${task.fileName}',
        headers: task.headers,
        fileName: task.fileName,
      ),
      onProgress: (progress) {
        if (progress.total != null && current.totalBytes != progress.total) {
          current = DownloadTask(
            id: id,
            provider: current.provider,
            subjectId: current.subjectId,
            title: current.title,
            season: current.season,
            episode: current.episode,
            url: current.url,
            headers: current.headers,
            fileName: current.fileName,
            posterUrl: task.posterUrl,
            totalBytes: progress.total,
            status: DownloadStatus.running,
            createdAt: current.createdAt,
          );
        }
        final state = DownloadState(
          task: current,
          progress: progress.fraction ?? 0,
          bytesPerSecond: progress.bytesPerSecond,
        );
        _states[id] = state;
        _controllers[id]?.add(state);
        if (!_globalController.isClosed) _globalController.add(state);
        _persistProgress(id, state);
      },
      isCancelled: () => _cancelled[id] ?? false,
    );

    final status = switch (result.outcome) {
      DownloadOutcome.completed => DownloadStatus.completed,
      DownloadOutcome.paused => DownloadStatus.paused,
      // A stopped download keeps its partial file and can be resumed.
      DownloadOutcome.cancelled => DownloadStatus.paused,
      DownloadOutcome.failed => DownloadStatus.failed,
    };

    current = DownloadTask(
      id: id,
      provider: task.provider,
      subjectId: task.subjectId,
      title: task.title,
      season: task.season,
      episode: task.episode,
      url: task.url,
      headers: task.headers,
      fileName: task.fileName,
      posterUrl: task.posterUrl,
      filePath: 'Downloads/${task.fileName}',
      totalBytes: result.bytes,
      downloadedBytes: result.bytes,
      status: status,
      error: result.error,
      integrity: result.integrity,
      createdAt: task.createdAt,
    );
    await _repository.update(current);
    _emit(current);

    if (result.outcome == DownloadOutcome.failed) {
      AppLogger.warn('download of ${task.fileName} failed: ${result.error}');
    }
  }

  void _emit(DownloadTask task) {
    final id = task.id;
    if (id == null) return;
    final state = DownloadState(task: task);
    _states[id] = state;
    _controllers[id]?.add(state);
    if (!_globalController.isClosed) _globalController.add(state);
  }

  String _buildFileName({
    required Release release,
    required MediaDetails details,
    required int season,
    required int episode,
  }) {
    final title = _safeSegment(details.title);
    final extension = _extensionOf(release.directUrl ?? '');
    final parts = <String>[];
    if (details.isSeries && season > 0) {
      parts.add(title);
      parts.add('S${season.toString().padLeft(2, '0')}');
      if (episode > 0) {
        parts.add('E${episode.toString().padLeft(2, '0')}');
      }
    } else {
      parts.add(title);
    }
    return '${parts.join(' ')}.$extension';
  }

  static String _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'mp4';
    final extension = path.substring(dot + 1).toLowerCase();
    const allowed = {'mp4', 'mkv', 'webm', 'ts', 'mov', 'avi', 'm4v'};
    return allowed.contains(extension) ? extension : 'mp4';
  }

  /// Makes a string safe to use as a file name.
  static String _safeSegment(String value) {
    var name = value.trim();
    if (name.length > 120) name = name.substring(0, 120);
    name = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    name = name.replaceAll(RegExp(r'[\x00-\x1f]'), '');
    name = name.replaceAll(RegExp(r'^[._\s]+|[._\s]+$'), '');
    if (name.isEmpty) return 'snigea_download';
    const reserved = {
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    };
    if (reserved.contains(name.toUpperCase())) return '${name}_';
    return name;
  }
}

/// Formats a byte count for the download list.
String formatDownloadSize(int bytes) => formatBytes(bytes);
