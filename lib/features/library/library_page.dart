import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/media.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../state/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/images.dart';

/// The library screen: watchlist, favourites and history.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Watchlist'),
            Tab(text: 'Favourites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _HistoryList(),
          _SavedList(kind: SavedKind.watchlist),
          _SavedList(kind: SavedKind.favourite),
        ],
      ),
    );
  }
}

class _SavedList extends ConsumerWidget {
  const _SavedList({required this.kind});

  final SavedKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(libraryEntriesProvider(kind));

    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        title: 'The library could not be loaded',
        message: '$error',
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyView(
            title: kind == SavedKind.watchlist
                ? 'Your watchlist is empty'
                : 'No favourites yet',
            message: kind == SavedKind.watchlist
                ? 'Add a title to the watchlist to find it here later.'
                : 'Mark a title as a favourite to keep it close.',
            icon: kind == SavedKind.watchlist
                ? Icons.bookmark_outline
                : Icons.favorite_outline,
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
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final entry = items[index];
            return _LibraryTile(
              entry: entry,
              kind: kind,
              onRemove: () => ref
                  .read(libraryRepositoryProvider)
                  .remove(kind, entry.provider, entry.subjectId),
            );
          },
        );
      },
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.entry,
    required this.kind,
    required this.onRemove,
  });

  final LibraryEntry entry;
  final SavedKind kind;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => context.push(
        '/title?provider=${entry.provider.cacheKey}'
        '&id=${Uri.encodeComponent(entry.subjectId)}',
      ),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 78,
              child: PosterImage(
                url: entry.posterUrl,
                width: 56,
                height: 78,
                borderRadius: AppSpacing.radiusSm,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.titleSmall,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      entry.provider.label,
                      if (entry.year != null) entry.year!,
                      entry.mediaType == MediaType.series ? 'Series' : 'Movie',
                    ].join(' · '),
                    style: context.typography.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: kind == SavedKind.watchlist
                  ? 'Remove from watchlist'
                  : 'Remove from favourites',
              icon: const Icon(Icons.close, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(progressEntriesProvider);

    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        title: 'The history could not be loaded',
        message: '$error',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyView(
            title: 'Nothing watched yet',
            message: 'Titles you start playing appear here.',
            icon: Icons.history,
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
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final entry = items[index];
            return _HistoryTile(entry: entry);
          },
        );
      },
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.entry});

  final ProgressEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => context.push(
        '/player?provider=${entry.provider.cacheKey}'
        '&id=${Uri.encodeComponent(entry.subjectId)}'
        '&season=${entry.season}&episode=${entry.episode}'
        '&title=${Uri.encodeComponent(entry.title)}',
      ),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 78,
              child: PosterImage(
                url: entry.posterUrl,
                width: 56,
                height: 78,
                borderRadius: AppSpacing.radiusSm,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.titleSmall,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.completed
                        ? 'Watched'
                        : 'Continue at ${_position(entry)}',
                    style: context.typography.caption,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: entry.fraction,
                      minHeight: 3,
                      backgroundColor: context.colors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(context.colors.accent),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove from history',
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => ref
                  .read(progressRepositoryProvider)
                  .remove(
                    entry.provider,
                    entry.subjectId,
                    season: entry.season,
                    episode: entry.episode,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _position(ProgressEntry entry) {
    final total = entry.durationMs;
    final position = entry.positionMs;
    if (total == null || total <= 0) return _clock(position);
    return '${_clock(position)} / ${_clock(total)}';
  }

  String _clock(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// The watchlist and the favourites.
final libraryEntriesProvider =
    StreamProvider.family<List<LibraryEntry>, SavedKind>((ref, kind) {
      final repository = ref.watch(libraryRepositoryProvider);
      return repository.watch(kind);
    });

/// The playback history.
final progressEntriesProvider = StreamProvider<List<ProgressEntry>>((ref) {
  final repository = ref.watch(progressRepositoryProvider);
  return repository.watchAll();
});
