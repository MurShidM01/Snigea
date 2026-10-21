import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:dio/dio.dart';

import '../../core/logging/app_logger.dart';
import '../../core/network/http_client_factory.dart';
import '../../core/text/subtitle_parser.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../../data/repositories/download_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../providers/content_provider.dart';
import '../../services/playback_service.dart';
import '../../state/app_providers.dart';

const Object _keep = Object();

/// The arguments of the player.
class PlayerArguments {
  const PlayerArguments({
    required this.provider,
    required this.subjectId,
    required this.season,
    required this.episode,
    this.title = '',
    this.local = false,
  });

  final ProviderKind provider;
  final String subjectId;
  final int season;
  final int episode;
  final String title;
  final bool local;

  @override
  bool operator ==(Object other) =>
      other is PlayerArguments &&
      other.provider == provider &&
      other.subjectId == subjectId &&
      other.season == season &&
      other.episode == episode &&
      other.local == local;

  @override
  int get hashCode => Object.hash(provider, subjectId, season, episode, local);
}

/// The state of the player.
class PlayerState {
  const PlayerState({
    this.isLoading = true,
    this.isBuffering = false,
    this.error,
    this.releases = const [],
    this.selectedRelease,
    this.details,
    this.subtitles = const [],
    this.selectedSubtitle,
    this.cues = const [],
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.rate = 1.0,
    this.hasNextEpisode = false,
    this.sourceLabel = '',
    this.season = 0,
    this.episode = 0,
    this.aspectRatio,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.selectedAudioTrack,
    this.selectedSubtitleTrack,
  });

  final bool isLoading;
  final bool isBuffering;
  final String? error;
  final List<Release> releases;
  final Release? selectedRelease;
  final MediaDetails? details;
  final List<SubtitleOption> subtitles;
  final SubtitleOption? selectedSubtitle;
  final List<SubtitleCue> cues;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final double rate;
  final bool hasNextEpisode;
  final String sourceLabel;

  /// The season that is played.
  final int season;

  /// The episode that is played.
  final int episode;

  /// The aspect ratio of the video, when the decoder reported it.
  final double? aspectRatio;

  /// The audio tracks that the stream advertises.
  final List<AudioTrack> audioTracks;

  /// The subtitle tracks that are embedded in the stream.
  final List<SubtitleTrack> subtitleTracks;

  final AudioTrack? selectedAudioTrack;
  final SubtitleTrack? selectedSubtitleTrack;

  PlayerState copyWith({
    bool? isLoading,
    bool? isBuffering,
    Object? error = _keep,
    List<Release>? releases,
    Release? selectedRelease,
    MediaDetails? details,
    List<SubtitleOption>? subtitles,
    SubtitleOption? selectedSubtitle,
    List<SubtitleCue>? cues,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    double? rate,
    bool? hasNextEpisode,
    String? sourceLabel,
    int? season,
    int? episode,
    double? aspectRatio,
    List<AudioTrack>? audioTracks,
    List<SubtitleTrack>? subtitleTracks,
    AudioTrack? selectedAudioTrack,
    SubtitleTrack? selectedSubtitleTrack,
  }) => PlayerState(
    isLoading: isLoading ?? this.isLoading,
    isBuffering: isBuffering ?? this.isBuffering,
    error: identical(error, _keep) ? this.error : error as String?,
    releases: releases ?? this.releases,
    selectedRelease: selectedRelease ?? this.selectedRelease,
    details: details ?? this.details,
    subtitles: subtitles ?? this.subtitles,
    selectedSubtitle: selectedSubtitle ?? this.selectedSubtitle,
    cues: cues ?? this.cues,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    isPlaying: isPlaying ?? this.isPlaying,
    rate: rate ?? this.rate,
    hasNextEpisode: hasNextEpisode ?? this.hasNextEpisode,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    season: season ?? this.season,
    episode: episode ?? this.episode,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    audioTracks: audioTracks ?? this.audioTracks,
    subtitleTracks: subtitleTracks ?? this.subtitleTracks,
    selectedAudioTrack: selectedAudioTrack ?? this.selectedAudioTrack,
    selectedSubtitleTrack: selectedSubtitleTrack ?? this.selectedSubtitleTrack,
  );
}

/// Drives the video player.
class PlayerController extends Notifier<PlayerState> {
  PlayerController(this.arguments);

  /// The title that is played.
  final PlayerArguments arguments;

  late final Player _player;
  late final VideoController _videoController;

  /// Whether the media engine could not be started.
  bool _engineFailed = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _progressTimer;

  ProviderKind _provider = ProviderKind.moviebox;
  String _subjectId = '';
  int _season = 0;
  int _episode = 0;
  String _title = '';
  bool _local = false;
  Duration _resumePosition = Duration.zero;
  bool _opened = false;

  @override
  PlayerState build() {
    final arguments = this.arguments;
    _provider = arguments.provider;
    _subjectId = arguments.subjectId;
    _season = arguments.season;
    _episode = arguments.episode;
    _title = arguments.title;
    _local = arguments.local;

    // The media engine can fail to start (a missing system library or a
    // plugin that is not registered). The failure is reported through the
    // state instead of crashing the screen.
    try {
      _player = Player();
      _videoController = VideoController(_player);
    } catch (error) {
      AppLogger.error('the media engine could not be started: $error');
      _engineFailed = true;
      return PlayerState(
        isLoading: false,
        error: 'The media engine could not be started: $error',
      );
    }

    _subscriptions.add(
      _player.stream.position.listen((position) {
        state = state.copyWith(position: position);
      }),
    );
    _subscriptions.add(
      _player.stream.duration.listen((duration) {
        state = state.copyWith(duration: duration);
      }),
    );
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        state = state.copyWith(isPlaying: playing);
      }),
    );
    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        state = state.copyWith(isBuffering: buffering);
      }),
    );
    _subscriptions.add(
      _player.stream.tracks.listen((tracks) {
        state = state.copyWith(
          audioTracks: tracks.audio,
          subtitleTracks: tracks.subtitle,
        );
      }),
    );
    _subscriptions.add(
      _player.stream.track.listen((track) {
        state = state.copyWith(
          selectedAudioTrack: track.audio,
          selectedSubtitleTrack: track.subtitle,
        );
      }),
    );
    _subscriptions.add(
      _player.stream.videoParams.listen((params) {
        final width = params.w;
        final height = params.h;
        if (width == null || height == null || height == 0) return;
        state = state.copyWith(aspectRatio: width / height);
      }),
    );
    _subscriptions.add(
      _player.stream.error.listen((error) {
        AppLogger.warn('player error: $error');
        state = state.copyWith(error: error);
      }),
    );

    ref.onDispose(() {
      _progressTimer?.cancel();
      for (final subscription in _subscriptions) {
        subscription.cancel();
      }
      // Store the final position so that the title can be continued later.
      unawaited(_saveProgress(completed: false));
      _player.dispose();
    });

    Future.microtask(_load);
    return const PlayerState();
  }

  /// The season that is currently played.
  int get currentSeason => _season;

  /// The episode that is currently played.
  int get currentEpisode => _episode;

  /// The media kit player.
  Player get player => _player;

  /// The video controller used by the [Video] widget.
  VideoController get videoController => _videoController;

  /// Whether the media engine is available.
  bool get hasEngine => !_engineFailed;

  /// The current volume of the player.
  double get volume => _player.state.volume;

  /// Changes the volume of the player.
  void setVolume(double volume) => _player.setVolume(volume);

  Future<void> _load() async {
    try {
      final registry = ref.read(providerRegistryProvider);
      final contentProvider = registry[_provider];

      MediaDetails? details;
      if (contentProvider != null) {
        try {
          details = await contentProvider.details(_subjectId);
        } catch (_) {
          details = null;
        }
      }

      final releases = await _loadReleases();
      if (releases.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No playable source is available for this title.',
        );
        return;
      }

      final resume = await ref
          .read(progressRepositoryProvider)
          .entry(_provider, _subjectId, season: _season, episode: _episode);
      _resumePosition = Duration(milliseconds: resume?.positionMs ?? 0);

      final hasNext = _hasNextEpisode(details);

      state = state.copyWith(
        isLoading: false,
        details: details,
        releases: releases,
        selectedRelease: releases.first,
        hasNextEpisode: hasNext,
        season: _season,
        episode: _episode,
      );

      await _open(resumes: true);
      _startProgressTimer();
    } catch (error) {
      state = state.copyWith(isLoading: false, error: '$error');
    }
  }

  Future<List<Release>> _loadReleases() async {
    final registry = ref.read(providerRegistryProvider);
    final provider = registry[_provider];
    if (provider is! ReleaseProvider) return const [];
    final releaseProvider = provider as ReleaseProvider;
    try {
      return await releaseProvider.episodeStreams(
        _subjectId,
        _season,
        _episode,
      );
    } catch (error) {
      AppLogger.warn('could not load the releases: $error');
      return const [];
    }
  }

  bool _hasNextEpisode(MediaDetails? details) {
    if (details == null || !details.isSeries) return false;
    for (final season in details.seasons) {
      if (season.number != _season) continue;
      for (final episode in season.episodes) {
        if (episode.number == _episode + 1) return true;
      }
    }
    return false;
  }

  /// Opens the currently selected release.
  Future<void> _open({bool resumes = false}) async {
    if (_local) {
      final opened = await _openLocal();
      if (opened) return;
    }
    final release = state.selectedRelease;
    if (release == null) return;

    final playbackService = ref.read(playbackServiceProvider);
    PlaybackSource source;
    try {
      source = await playbackService.resolve(release, subjectId: _subjectId);
    } catch (error) {
      state = state.copyWith(error: '$error');
      return;
    }

    final headers = <String, String>{
      for (final header in source.headers) header.key: header.value,
    };

    await _player.open(
      Media(
        source.url,
        httpHeaders: headers.isEmpty ? null : headers,
        start: resumes && _resumePosition > Duration.zero
            ? _resumePosition
            : null,
      ),
    );
    _opened = true;
    state = state.copyWith(error: null, sourceLabel: source.sourceLabel);

    await _loadSubtitles(release);
  }

  /// Opens the downloaded file of a title, if it exists.
  Future<bool> _openLocal() async {
    final tasks = await ref.read(downloadRepositoryProvider).all();
    DownloadTask? match;
    for (final task in tasks) {
      if (task.provider != _provider) continue;
      if (task.subjectId != _subjectId) continue;
      if (task.season != _season || task.episode != _episode) continue;
      if (task.status != DownloadStatus.completed) continue;
      match = task;
      break;
    }
    if (match == null || match.filePath == null) return false;

    final fileStore = ref.read(fileStoreProvider);
    final path = await fileStore.absolutePath(match.filePath!);
    if (!await fileStore.exists(match.filePath!)) return false;

    await _player.open(Media(path));
    _opened = true;
    state = state.copyWith(error: null, sourceLabel: 'Downloaded file');
    return true;
  }

  Future<void> _loadSubtitles(Release release) async {
    if (_provider != ProviderKind.moviebox) return;
    final resourceId = release.resourceId;
    if (resourceId == null || resourceId.isEmpty) return;

    final client = ref.read(movieBoxClientProvider);
    try {
      final payload = await client.extCaptions(_subjectId, resourceId);
      final options = MovieBoxSubtitles.parse(payload);
      state = state.copyWith(subtitles: options);
    } catch (error) {
      AppLogger.warn('could not load the subtitles: $error');
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_opened) return;
      await _saveProgress(completed: false);
    });
  }

  Future<void> _saveProgress({required bool completed}) async {
    final position = state.position;
    final duration = state.duration;
    final details = state.details;
    await ref
        .read(progressRepositoryProvider)
        .save(
          ProgressEntry(
            provider: _provider,
            subjectId: _subjectId,
            title: details?.title ?? _title,
            mediaType: details?.mediaType ?? MediaType.movie,
            season: _season,
            episode: _episode,
            positionMs: position.inMilliseconds,
            durationMs: duration.inMilliseconds,
            completed: completed,
            posterUrl: details?.posterUrl,
            year: details?.year,
            sourceLabel: state.sourceLabel,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    if (completed) {
      await ref
          .read(progressRepositoryProvider)
          .markWatched(
            provider: _provider,
            subjectId: _subjectId,
            title: details?.title ?? _title,
            season: _season,
            episode: _episode,
          );
    }
  }

  // ------------------------------------------------------------- commands

  /// Toggles between play and pause.
  void togglePlay() => _player.playOrPause();

  /// Seeks to [position].
  void seek(Duration position) => _player.seek(position);

  /// Seeks by [offset].
  void seekBy(Duration offset) {
    final target = state.position + offset;
    final duration = state.duration;
    if (duration > Duration.zero && target > duration) {
      _player.seek(duration);
      return;
    }
    if (target < Duration.zero) {
      _player.seek(Duration.zero);
      return;
    }
    _player.seek(target);
  }

  /// Changes the playback speed.
  void setRate(double rate) {
    _player.setRate(rate);
    state = state.copyWith(rate: rate);
  }

  /// Switches to another release.
  Future<void> selectRelease(Release release) async {
    state = state.copyWith(selectedRelease: release, isLoading: true);
    await _open();
    state = state.copyWith(isLoading: false);
  }

  /// Selects an external subtitle track and renders it in the app.
  Future<void> selectSubtitle(SubtitleOption? option) async {
    state = state.copyWith(selectedSubtitle: option, cues: const []);
    if (option == null) return;
    try {
      final content = await _downloadSubtitle(option.url);
      state = state.copyWith(cues: SubtitleParser.parse(content));
    } catch (error) {
      AppLogger.warn('could not load the subtitle: $error');
      state = state.copyWith(error: 'The subtitle could not be loaded.');
    }
  }

  Future<String> _downloadSubtitle(String url) async {
    final dio = HttpClientFactory.create(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    );
    final response = await dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw StateError('The subtitle request failed with HTTP $status');
    }
    return response.data ?? '';
  }

  /// Changes the audio track.
  void selectAudioTrack(AudioTrack track) {
    _player.setAudioTrack(track);
    state = state.copyWith(selectedAudioTrack: track);
  }

  /// Changes the embedded subtitle track.
  void selectSubtitleTrack(SubtitleTrack track) {
    _player.setSubtitleTrack(track);
    state = state.copyWith(selectedSubtitleTrack: track);
  }

  /// Marks the episode as watched and moves on.
  Future<void> completeAndContinue() async {
    await _saveProgress(completed: true);
    final details = state.details;
    if (details == null || !state.hasNextEpisode) return;
    final nextEpisode = _episode + 1;
    _episode = nextEpisode;
    final releases = await _loadReleases();
    if (releases.isEmpty) {
      state = state.copyWith(error: 'The next episode is not available.');
      return;
    }
    state = state.copyWith(
      releases: releases,
      selectedRelease: releases.first,
      hasNextEpisode: _hasNextEpisode(details),
    );
    await _open();
  }

  /// Retries after a playback error.
  Future<void> retry() async {
    state = state.copyWith(error: null, isLoading: true);
    await _open();
    state = state.copyWith(isLoading: false);
  }

  /// Saves the progress when the player is closed.
  Future<void> saveProgress() => _saveProgress(completed: false);
}

/// The player state.
///
/// The title is part of the key, so every player owns its own media engine
/// and the engine is released as soon as the screen is closed.
final playerControllerProvider = NotifierProvider.family
    .autoDispose<PlayerController, PlayerState, PlayerArguments>(
      PlayerController.new,
    );
