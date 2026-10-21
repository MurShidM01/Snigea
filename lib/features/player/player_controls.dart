import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

import '../../core/theme/app_spacing.dart';
import '../../data/models/media.dart';
import '../../data/models/release.dart';
import 'player_controller.dart';

/// The playback controls of the player.
///
/// The layout follows the conventions of the large streaming apps: a gradient
/// scrim at the top and the bottom, a large play button in the centre and a
/// seek bar with the elapsed and the remaining time.
class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.state,
    required this.locked,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onSeekBy,
    required this.onToggleLock,
    required this.onToggleFullscreen,
    required this.onRate,
    required this.onSelectRelease,
    required this.onSelectSubtitle,
    required this.onSelectAudioTrack,
    required this.onSelectSubtitleTrack,
    required this.onClose,
    required this.title,
    this.onNext,
    this.onDownload,
  });

  final PlayerState state;
  final bool locked;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onSeekBy;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleFullscreen;
  final ValueChanged<double> onRate;
  final ValueChanged<Release> onSelectRelease;
  final ValueChanged<SubtitleOption?> onSelectSubtitle;
  final ValueChanged<AudioTrack> onSelectAudioTrack;
  final ValueChanged<SubtitleTrack> onSelectSubtitleTrack;
  final VoidCallback onClose;
  final VoidCallback? onNext;
  final VoidCallback? onDownload;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.85),
          ],
          stops: const [0, 0.28, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: title,
              sourceLabel: state.sourceLabel,
              onClose: onClose,
              onSelectRelease: (context) => _showSources(context),
              onSelectSubtitle: (context) => _showSubtitles(context),
              onSelectTracks: (context) => _showTracks(context),
              onToggleLock: onToggleLock,
              onToggleFullscreen: onToggleFullscreen,
            ),
            const Spacer(),
            _CenterControls(
              isPlaying: state.isPlaying,
              onTogglePlay: onTogglePlay,
              onSkipBack: () => onSeekBy(const Duration(seconds: -10)),
              onSkipForward: () => onSeekBy(const Duration(seconds: 10)),
              onNext: onNext,
            ),
            const Spacer(),
            _BottomBar(
              state: state,
              onSeek: onSeek,
              onRate: onRate,
              onDownload: onDownload,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSources(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15171D),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const _SheetTitle('Sources'),
            RadioGroup<Release>(
              groupValue: state.selectedRelease,
              onChanged: (value) {
                if (value == null) return;
                Navigator.of(context).pop();
                onSelectRelease(value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final release in state.releases)
                    RadioListTile<Release>(
                      value: release,
                      title: Text(
                        release.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (release.quality != null) release.quality!,
                          if (release.codec != null) release.codec!,
                          release.sourceLabel,
                          if (release.sizeBytes != null)
                            _size(release.sizeBytes!),
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9AA3B2),
                        ),
                      ),
                      activeColor: const Color(0xFF4EA8FF),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubtitles(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15171D),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const _SheetTitle('Subtitles'),
            ListTile(
              leading: const Icon(Icons.closed_caption_outlined),
              title: const Text('Off'),
              trailing: state.selectedSubtitle == null
                  ? const Icon(Icons.check, color: Color(0xFF4EA8FF))
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                onSelectSubtitle(null);
              },
            ),
            for (final option in state.subtitles)
              ListTile(
                leading: const Icon(Icons.closed_caption),
                title: Text(option.name),
                trailing: state.selectedSubtitle?.url == option.url
                    ? const Icon(Icons.check, color: Color(0xFF4EA8FF))
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelectSubtitle(option);
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _showTracks(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15171D),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const _SheetTitle('Audio and speed'),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Playback speed'),
              subtitle: Text('${state.rate.toStringAsFixed(2)}x'),
              trailing: state.rate == 1.0
                  ? const Icon(Icons.check, color: Color(0xFF4EA8FF))
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                _showSpeed(context);
              },
            ),
            if (state.audioTracks.length > 1) ...[
              const _SheetLabel('Audio'),
              for (final track in state.audioTracks)
                ListTile(
                  title: Text(
                    track.title ?? track.language ?? track.id,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  trailing: state.selectedAudioTrack?.id == track.id
                      ? const Icon(Icons.check, color: Color(0xFF4EA8FF))
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelectAudioTrack(track);
                  },
                ),
            ],
            if (state.subtitleTracks.length > 1) ...[
              const _SheetLabel('Embedded subtitles'),
              for (final track in state.subtitleTracks)
                ListTile(
                  title: Text(
                    track.title ?? track.language ?? track.id,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  trailing: state.selectedSubtitleTrack?.id == track.id
                      ? const Icon(Icons.check, color: Color(0xFF4EA8FF))
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelectSubtitleTrack(track);
                  },
                ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _showSpeed(BuildContext context) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15171D),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetTitle('Playback speed'),
            for (final speed in speeds)
              ListTile(
                title: Text('${speed.toStringAsFixed(2)}x'),
                trailing: state.rate == speed
                    ? const Icon(Icons.check, color: Color(0xFF4EA8FF))
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  onRate(speed);
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  static String _size(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit <= 1 ? 0 : 1)} ${units[unit]}';
  }
}

/// The compact control bar of the mini player.
class MiniPlayerControls extends StatelessWidget {
  const MiniPlayerControls({
    super.key,
    required this.state,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onExpand,
    required this.onNext,
  });

  final PlayerState state;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onExpand;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final duration = state.duration;
    final position = state.position;
    final max = duration.inMilliseconds.toDouble();
    final value = max <= 0
        ? 0.0
        : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 30,
            color: Colors.white,
            icon: Icon(
              state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            onPressed: onTogglePlay,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: const Color(0xFF4EA8FF),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFF4EA8FF),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                max: max <= 0 ? 1 : max,
                onChanged: max <= 0
                    ? null
                    : (newValue) =>
                          onSeek(Duration(milliseconds: newValue.round())),
              ),
            ),
          ),
          Text(
            '${_clock(position)} / ${_clock(duration)}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFFBFC6D1),
            ),
          ),
          if (onNext != null)
            IconButton(
              iconSize: 24,
              color: Colors.white,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: onNext,
            ),
          IconButton(
            iconSize: 24,
            color: Colors.white,
            icon: const Icon(Icons.fullscreen),
            onPressed: onExpand,
          ),
        ],
      ),
    );
  }

  String _clock(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ).copyWith(color: Colors.white),
    ),
  );
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: Color(0xFF8A93A2),
      ).copyWith(color: const Color(0xFF8A93A2)),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.sourceLabel,
    required this.onClose,
    required this.onSelectRelease,
    required this.onSelectSubtitle,
    required this.onSelectTracks,
    required this.onToggleLock,
    required this.onToggleFullscreen,
  });

  final String title;
  final String sourceLabel;
  final VoidCallback onClose;
  final void Function(BuildContext context) onSelectRelease;
  final void Function(BuildContext context) onSelectSubtitle;
  final void Function(BuildContext context) onSelectTracks;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ).copyWith(color: Colors.white),
                ),
                if (sourceLabel.isNotEmpty)
                  Text(
                    sourceLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9AA3B2),
                    ).copyWith(color: const Color(0xFF9AA3B2)),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sources',
            icon: const Icon(Icons.high_quality_outlined),
            color: Colors.white,
            onPressed: () => onSelectRelease(context),
          ),
          IconButton(
            tooltip: 'Subtitles',
            icon: const Icon(Icons.closed_caption_outlined),
            color: Colors.white,
            onPressed: () => onSelectSubtitle(context),
          ),
          IconButton(
            tooltip: 'Audio and speed',
            icon: const Icon(Icons.tune),
            color: Colors.white,
            onPressed: () => onSelectTracks(context),
          ),
          IconButton(
            tooltip: 'Lock the controls',
            icon: const Icon(Icons.lock_outline),
            color: Colors.white,
            onPressed: onToggleLock,
          ),
          IconButton(
            tooltip: 'Fullscreen',
            icon: const Icon(Icons.fullscreen),
            color: Colors.white,
            onPressed: onToggleFullscreen,
          ),
        ],
      ),
    );
  }
}

class _CenterControls extends StatelessWidget {
  const _CenterControls({
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onSkipBack,
    required this.onSkipForward,
    this.onNext,
  });

  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          icon: Icons.replay_10_rounded,
          size: 34,
          onPressed: onSkipBack,
        ),
        const SizedBox(width: AppSpacing.xl),
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 42,
            padding: EdgeInsets.zero,
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
            ),
            onPressed: onTogglePlay,
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        _RoundButton(
          icon: Icons.forward_10_rounded,
          size: 34,
          onPressed: onSkipForward,
        ),
        if (onNext != null) ...[
          const SizedBox(width: AppSpacing.xl),
          _RoundButton(
            icon: Icons.skip_next_rounded,
            size: 30,
            onPressed: onNext!,
          ),
        ],
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    iconSize: size,
    color: Colors.white,
    icon: Icon(icon),
    onPressed: onPressed,
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.onSeek,
    required this.onRate,
    this.onDownload,
  });

  final PlayerState state;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onRate;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final duration = state.duration;
    final position = state.position;
    final max = duration.inMilliseconds.toDouble();
    final value = max <= 0
        ? 0.0
        : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: const Color(0xFF4EA8FF),
              inactiveTrackColor: Colors.white24,
              thumbColor: const Color(0xFF4EA8FF),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0
                  ? null
                  : (newValue) =>
                        onSeek(Duration(milliseconds: newValue.round())),
            ),
          ),
          Row(
            children: [
              Text(
                _clock(position),
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9AA3B2),
                ).copyWith(color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '-${_clock(duration - position)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9AA3B2),
                  ).copyWith(color: Colors.white),
                ),
              ),
              if (onDownload != null)
                IconButton(
                  tooltip: 'Download',
                  icon: const Icon(Icons.download_outlined, size: 20),
                  color: Colors.white,
                  onPressed: onDownload,
                ),
              TextButton(
                onPressed: () => onRate(state.rate == 1.0 ? 1.5 : 1.0),
                child: Text(
                  '${state.rate.toStringAsFixed(2)}x',
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9AA3B2),
                  ).copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _clock(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
