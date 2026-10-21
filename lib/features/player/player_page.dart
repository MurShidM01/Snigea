import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../../features/home/home_controller.dart';
import '../../state/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_card.dart';
import 'player_controller.dart';
import 'player_controls.dart';
import 'video_surface.dart';

/// The full screen video player.
class PlayerPage extends StatelessWidget {
  const PlayerPage({
    super.key,
    required this.provider,
    required this.subjectId,
    required this.season,
    required this.episode,
    required this.title,
    this.local = false,
  });

  final String provider;
  final String subjectId;
  final int season;
  final int episode;
  final String title;
  final bool local;

  @override
  Widget build(BuildContext context) {
    final arguments = PlayerArguments(
      provider: ProviderKind.tryParse(provider) ?? ProviderKind.moviebox,
      subjectId: subjectId,
      season: season,
      episode: episode,
      title: title,
      local: local,
    );

    return _PlayerView(arguments: arguments);
  }
}

class _PlayerView extends ConsumerStatefulWidget {
  const _PlayerView({required this.arguments});

  final PlayerArguments arguments;

  @override
  ConsumerState<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<_PlayerView> {
  bool _controlsVisible = true;
  bool _locked = false;

  /// The player opens as a mini player, the fullscreen is one tap away.
  bool _isFullscreen = false;
  Timer? _hideTimer;
  double _seekIndicator = 0;
  double _dragDelta = 0;
  bool _swipeForward = true;
  double _volume = 1;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The mini player follows the orientation of the device, the fullscreen
    // switches to the landscape.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_locked) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final provider = playerControllerProvider(widget.arguments);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return Scaffold(
      backgroundColor: _isFullscreen ? Colors.black : context.colors.background,
      body: _isFullscreen
          ? _immersive(context, state, controller)
          : _mini(context, state, controller),
    );
  }

  /// The mini player: the video with its controls, the actions and the
  /// recommendations below, like the inline player of the streaming apps.
  Widget _mini(
    BuildContext context,
    PlayerState state,
    PlayerController controller,
  ) {
    final details = state.details;
    final recommendations = ref.watch(
      homeControllerProvider(widget.arguments.provider),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              // The video with the compact control bar.
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (controller.hasEngine)
                        VideoSurface(
                          aspectRatio: state.aspectRatio,
                          child: Video(
                            controller: controller.videoController,
                            fit: BoxFit.contain,
                            fill: Colors.black,
                            controls: NoVideoControls,
                            wakelock: true,
                          ),
                        ),
                      if (state.isBuffering || state.isLoading)
                        const Center(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (state.error != null)
                        _ErrorOverlay(
                          message: state.error!,
                          onRetry: () => controller.retry(),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                              ],
                            ),
                          ),
                          child: MiniPlayerControls(
                            state: state,
                            onTogglePlay: controller.togglePlay,
                            onSeek: controller.seek,
                            onExpand: _toggleFullscreen,
                            onNext: state.hasNextEpisode
                                ? () => controller.completeAndContinue()
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.lg,
                  AppSpacing.gutter,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details?.title ?? widget.arguments.title,
                      style: context.typography.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        if (details?.year != null) details!.year!,
                        if (state.season > 0 && state.episode > 0)
                          'S${state.season.toString().padLeft(2, '0')}'
                              'E${state.episode.toString().padLeft(2, '0')}',
                        if (state.sourceLabel.isNotEmpty) state.sourceLabel,
                      ].join(' · '),
                      style: context.typography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: controller.togglePlay,
                          icon: Icon(
                            state.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          label: Text(state.isPlaying ? 'Pause' : 'Play'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _toggleFullscreen,
                          icon: const Icon(Icons.fullscreen, size: 18),
                          label: const Text('Fullscreen'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openSources(context, state),
                          icon: const Icon(
                            Icons.high_quality_outlined,
                            size: 18,
                          ),
                          label: const Text('Sources'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openSubtitles(context, state),
                          icon: const Icon(
                            Icons.closed_caption_outlined,
                            size: 18,
                          ),
                          label: const Text('Subtitles'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openTracks(context, state),
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('Audio & speed'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (state.releases.isNotEmpty)
                _MiniSources(
                  state: state,
                  onSelect: (release) => controller.selectRelease(release),
                ),
            ],
          ),
        ),
        // The recommendations of the provider of the title.
        ...recommendations.when(
          loading: () => const <Widget>[SliverToBoxAdapter(child: SizedBox())],
          error: (error, _) => const <Widget>[
            SliverToBoxAdapter(child: SizedBox()),
          ],
          data: (home) {
            final items = <CatalogItem>[];
            for (final section in home.sections) {
              items.addAll(section.items);
              if (items.length >= 20) break;
            }
            if (items.isEmpty) {
              return const <Widget>[SliverToBoxAdapter(child: SizedBox())];
            }
            return <Widget>[
              SliverToBoxAdapter(
                child: MediaRow(
                  title: 'For you',
                  subtitle: 'More from ${widget.arguments.provider.label}',
                  items: items.take(20).toList(),
                  onOpen: (item) => context.push(
                    '/title?provider=${item.id.provider.cacheKey}'
                    '&id=${Uri.encodeComponent(item.id.value)}',
                  ),
                ),
              ),
            ];
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
      ],
    );
  }

  Future<void> _openSources(BuildContext context, PlayerState state) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surfaceElevated,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text('Sources', style: context.typography.titleMedium),
            ),
            for (final release in state.releases)
              ListTile(
                title: Text(
                  release.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (release.quality != null) release.quality!,
                    if (release.language != null) release.language!,
                    release.sourceLabel,
                  ].join(' · '),
                  style: context.typography.caption,
                ),
                selected: state.selectedRelease == release,
                onTap: () {
                  Navigator.of(context).pop();
                  ref
                      .read(playerControllerProvider(widget.arguments).notifier)
                      .selectRelease(release);
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubtitles(BuildContext context, PlayerState state) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surfaceElevated,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text('Subtitles', style: context.typography.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.closed_caption_outlined),
              title: const Text('Off'),
              trailing: state.selectedSubtitle == null
                  ? Icon(Icons.check, color: context.colors.accent)
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                ref
                    .read(playerControllerProvider(widget.arguments).notifier)
                    .selectSubtitle(null);
              },
            ),
            for (final option in state.subtitles)
              ListTile(
                leading: const Icon(Icons.closed_caption),
                title: Text(option.name),
                trailing: state.selectedSubtitle?.url == option.url
                    ? Icon(Icons.check, color: context.colors.accent)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  ref
                      .read(playerControllerProvider(widget.arguments).notifier)
                      .selectSubtitle(option);
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _openTracks(BuildContext context, PlayerState state) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surfaceElevated,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Audio and speed',
                style: context.typography.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Playback speed'),
              subtitle: Text('${state.rate.toStringAsFixed(2)}x'),
              onTap: () {
                Navigator.of(context).pop();
                _openSpeed(context, state);
              },
            ),
            for (final track in state.audioTracks)
              ListTile(
                title: Text(track.title ?? track.language ?? track.id),
                trailing: state.selectedAudioTrack?.id == track.id
                    ? Icon(Icons.check, color: context.colors.accent)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  ref
                      .read(playerControllerProvider(widget.arguments).notifier)
                      .selectAudioTrack(track);
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _openSpeed(BuildContext context, PlayerState state) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surfaceElevated,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Playback speed',
                style: context.typography.titleMedium,
              ),
            ),
            for (final speed in speeds)
              ListTile(
                title: Text('${speed.toStringAsFixed(2)}x'),
                trailing: state.rate == speed
                    ? Icon(Icons.check, color: context.colors.accent)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  ref
                      .read(playerControllerProvider(widget.arguments).notifier)
                      .setRate(speed);
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  /// The immersive layout that fills the screen.
  Widget _immersive(
    BuildContext context,
    PlayerState state,
    PlayerController controller,
  ) {
    final cue = _currentCue(state);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_locked) return;
        setState(() => _controlsVisible = !_controlsVisible);
        if (_controlsVisible) _scheduleHide();
      },
      onDoubleTapDown: (details) => _seekIndicator = details.localPosition.dx,
      onDoubleTap: () => _handleDoubleTap(controller),
      onHorizontalDragStart: (details) {
        _dragDelta = 0;
      },
      onHorizontalDragUpdate: (details) {
        _dragDelta += details.delta.dx;
        if (details.delta.dx.abs() > 0.5) {
          _swipeForward = details.delta.dx > 0;
        }
        // Sixty pixels are one seek step of ten seconds.
        const pixelsPerStep = 60.0;
        while (_dragDelta.abs() >= pixelsPerStep) {
          final forward = _dragDelta > 0;
          controller.seekBy(Duration(seconds: forward ? 10 : -10));
          _dragDelta -= forward ? pixelsPerStep : -pixelsPerStep;
        }
        setState(() => _seekIndicator = details.localPosition.dx);
        _showControls();
      },
      onHorizontalDragEnd: (details) => setState(() => _seekIndicator = 0),
      onVerticalDragUpdate: (details) {
        // The lower half of the screen changes the volume.
        final height = MediaQuery.sizeOf(context).height;
        if (details.localPosition.dy < height / 2) return;
        final volume = (_volume - details.delta.dy / 400).clamp(0.0, 1.0);
        controller.setVolume(volume);
        setState(() => _volume = volume);
        _showControls();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The video fills the whole surface, the letterbox areas stay
          // black. The surface forces the bounded constraints onto the
          // video output.
          if (controller.hasEngine)
            VideoSurface(
              child: Video(
                controller: controller.videoController,
                fit: BoxFit.contain,
                fill: Colors.black,
                controls: NoVideoControls,
                wakelock: true,
              ),
            ),
          if (state.isBuffering || state.isLoading)
            const Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
          if (cue != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: _controlsVisible ? 160 : 90,
              child: _SubtitleOverlay(text: cue),
            ),
          if (_seekIndicator != 0)
            Positioned(
              top: 0,
              bottom: 0,
              left: _seekIndicator < MediaQuery.sizeOf(context).width / 2
                  ? 24
                  : null,
              right: _seekIndicator < MediaQuery.sizeOf(context).width / 2
                  ? null
                  : 24,
              child: Center(child: _SeekIndicator(forward: _swipeForward)),
            ),
          if (state.error != null)
            _ErrorOverlay(
              message: state.error!,
              onRetry: () => controller.retry(),
            ),
          if (_controlsVisible && state.error == null && !_locked)
            PlayerControls(
              state: state,
              locked: _locked,
              onTogglePlay: () {
                controller.togglePlay();
                _scheduleHide();
              },
              onSeek: (position) {
                controller.seek(position);
                _scheduleHide();
              },
              onSeekBy: (offset) {
                controller.seekBy(offset);
                _scheduleHide();
              },
              onToggleLock: () => setState(() => _locked = !_locked),
              onToggleFullscreen: _toggleFullscreen,
              onRate: (rate) {
                controller.setRate(rate);
                _scheduleHide();
              },
              onSelectRelease: (release) {
                controller.selectRelease(release);
                _showControls();
              },
              onSelectSubtitle: (option) {
                controller.selectSubtitle(option);
                _showControls();
              },
              onSelectAudioTrack: controller.selectAudioTrack,
              onSelectSubtitleTrack: controller.selectSubtitleTrack,
              onNext: state.hasNextEpisode
                  ? () {
                      controller.completeAndContinue();
                      _showControls();
                    }
                  : null,
              onClose: () => context.pop(),
              onDownload: () => _download(context, controller, state),
              title: widgetTitle(state),
            )
          else if (!_locked)
            _HiddenProgress(state: state),
          if (_volumeIndicator != null)
            Positioned(
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(child: _volumeIndicator!),
            ),
          if (_locked)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 56,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _locked = false),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String widgetTitle(PlayerState state) {
    final details = state.details;
    if (details == null) return '';
    if (details.isSeries && state.hasNextEpisode) {
      return '${details.title} · S${state.season} E${state.episode}';
    }
    return details.title;
  }

  Widget? get _volumeIndicator {
    if (_volume == 1) return null;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _volume == 0 ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 64,
            child: LinearProgressIndicator(
              value: _volume,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4EA8FF)),
            ),
          ),
        ],
      ),
    );
  }

  String? _currentCue(PlayerState state) {
    for (final cue in state.cues) {
      if (state.position >= cue.start && state.position <= cue.end) {
        return cue.text;
      }
    }
    return null;
  }

  void _handleDoubleTap(PlayerController controller) {
    final width = MediaQuery.sizeOf(context).width;
    if (_seekIndicator < width / 3) {
      controller.seekBy(const Duration(seconds: -10));
    } else if (_seekIndicator > width * 2 / 3) {
      controller.seekBy(const Duration(seconds: 10));
    }
    _showControls();
  }

  Future<void> _download(
    BuildContext context,
    PlayerController controller,
    PlayerState state,
  ) async {
    final release = state.selectedRelease;
    final details = state.details;
    if (release == null || details == null) return;
    final service = ref.read(downloadServiceProvider);
    if (!service.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            service.unsupportedReason ?? 'Downloads are unavailable',
          ),
        ),
      );
      return;
    }
    await service.enqueue(
      release: release,
      details: details,
      season: controller.currentSeason,
      episode: controller.currentEpisode,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('The download was queued')));
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }
}

class _SubtitleOverlay extends StatelessWidget {
  const _SubtitleOverlay({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

class _SeekIndicator extends StatelessWidget {
  const _SeekIndicator({required this.forward});

  final bool forward;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(
        forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}

class _HiddenProgress extends StatelessWidget {
  const _HiddenProgress({required this.state});

  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final duration = state.duration.inMilliseconds;
    final position = state.position.inMilliseconds;
    final value = duration <= 0 ? 0.0 : position / duration;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 2,
        backgroundColor: Colors.white24,
        valueColor: const AlwaysStoppedAnimation(Color(0xFF4EA8FF)),
      ),
    );
  }
}

/// The list of the sources in the mini player.
class _MiniSources extends StatelessWidget {
  const _MiniSources({required this.state, required this.onSelect});

  final PlayerState state;
  final ValueChanged<Release> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Sources',
          subtitle: 'Every quality and audio track of this title',
        ),
        for (final release in state.releases)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: InkWell(
              onTap: () => onSelect(release),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: state.selectedRelease == release
                        ? context.colors.accent
                        : context.colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            release.filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            [
                              if (release.quality != null) release.quality!,
                              if (release.language != null) release.language!,
                              release.sourceLabel,
                            ].join(' · '),
                            style: context.typography.caption,
                          ),
                        ],
                      ),
                    ),
                    if (state.selectedRelease == release)
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: context.colors.accent,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: const Color(0xFF15171D),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: const Color(0xFF2A2F3A)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF5C6C), size: 30),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A release that the player can hand over to the download service.
typedef DownloadableRelease = Release;
