import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/download_repository.dart';
import '../../services/download_service.dart';
import '../../state/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/images.dart';

/// The download manager screen.
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(downloadRepositoryProvider);
    final tasks = ref.watch(downloadTasksProvider);
    final service = ref.watch(downloadServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Remove finished downloads',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () => repository.clearFinished(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: !service.isSupported
          ? ErrorView(
              title: 'Downloads are unavailable',
              message:
                  service.unsupportedReason ??
                  'This platform cannot store files on disk.',
              icon: Icons.sd_storage_outlined,
            )
          : tasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                title: 'The downloads could not be loaded',
                message: '$error',
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyView(
                    title: 'No downloads yet',
                    message:
                        'Open a title, pick a source and use the download '
                        'button to save it for offline viewing.',
                    icon: Icons.download_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.md,
                    AppSpacing.gutter,
                    AppSpacing.xxxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final task = items[index];
                    return _DownloadTile(task: task);
                  },
                );
              },
            ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(downloadServiceProvider);

    // The live progress of the service wins over the stored record, so the
    // bar moves while the download runs.
    return StreamBuilder<DownloadState>(
      stream: service.watch(task.id ?? -1),
      builder: (context, snapshot) {
        final live = snapshot.data;
        final current = live?.task ?? task;
        final progress = live?.progress ?? task.fraction ?? 0;
        final running = current.status == DownloadStatus.running;
        final failed = current.status == DownloadStatus.failed;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The poster of the title.
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: SizedBox(
                  width: 42,
                  height: 58,
                  child: PosterImage(
                    url: current.posterUrl,
                    width: 42,
                    height: 58,
                    borderRadius: AppSpacing.radiusSm,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            current.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.titleSmall,
                          ),
                        ),
                        _StatusLabel(status: current.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: current.status == DownloadStatus.completed
                            ? 1
                            : progress.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: context.colors.surfaceHigh,
                        valueColor: AlwaysStoppedAnimation(
                          failed
                              ? context.colors.danger
                              : context.colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            current.error ??
                                _detail(running, progress, current),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.caption.copyWith(
                              color: current.error == null
                                  ? context.colors.textTertiary
                                  : context.colors.danger,
                            ),
                          ),
                        ),
                        if (running || current.status == DownloadStatus.queued)
                          IconButton(
                            tooltip: 'Pause',
                            icon: const Icon(
                              Icons.pause_circle_outline,
                              size: 20,
                            ),
                            onPressed: () => service.pause(current),
                          ),
                        if (current.status == DownloadStatus.paused ||
                            current.status == DownloadStatus.failed)
                          IconButton(
                            tooltip: 'Resume',
                            icon: const Icon(
                              Icons.play_circle_outline,
                              size: 20,
                            ),
                            onPressed: () => service.resume(current),
                          ),
                        if (current.status == DownloadStatus.completed)
                          IconButton(
                            tooltip: 'Play',
                            icon: const Icon(
                              Icons.play_circle_outline,
                              size: 20,
                            ),
                            onPressed: () => context.push(
                              '/player?provider=${current.provider.cacheKey}'
                              '&id=${Uri.encodeComponent(current.subjectId)}'
                              '&season=${current.season}&episode=${current.episode}'
                              '&title=${Uri.encodeComponent(current.title)}'
                              '&local=1',
                            ),
                          ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => service.remove(current),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _detail(bool running, double progress, DownloadTask task) {
    final total = task.totalBytes;
    final size = total == null ? '' : ' · ${_size(total)}';
    if (running) return '${(progress * 100).toStringAsFixed(0)}%$size';
    return '${task.status.wireName}$size';
  }

  String _size(int bytes) {
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

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DownloadStatus.completed => context.colors.success,
      DownloadStatus.failed => context.colors.danger,
      DownloadStatus.running => context.colors.accent,
      DownloadStatus.paused => context.colors.warning,
      _ => context.colors.textTertiary,
    };
    final label = switch (status) {
      DownloadStatus.completed => 'Completed',
      DownloadStatus.failed => 'Failed',
      DownloadStatus.running => 'Downloading',
      DownloadStatus.paused => 'Paused',
      DownloadStatus.queued => 'Queued',
      DownloadStatus.cancelled => 'Cancelled',
    };
    return Text(
      label,
      style: context.typography.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
