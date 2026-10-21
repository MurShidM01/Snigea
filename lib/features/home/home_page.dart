import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/repositories/progress_repository.dart';
import '../../state/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/logo.dart';
import '../../widgets/provider_chip.dart';
import '../../widgets/images.dart';
import '../../widgets/media_card.dart';
import 'home_controller.dart';

/// The discovery screen.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final activeProvider = settings?.activeProvider ?? ProviderKind.moviebox;
    final home = ref.watch(homeControllerProvider(activeProvider));

    return Scaffold(
      body: RefreshIndicator(
        color: context.colors.accent,
        backgroundColor: context.colors.surfaceElevated,
        onRefresh: () =>
            ref.read(homeControllerProvider(activeProvider).notifier).refresh(),
        child: CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 132,
              backgroundColor: context.colors.background,
              surfaceTintColor: Colors.transparent,
              title: _BrandMark(),
              actions: [
                if (settings != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: ProviderChip(
                      provider: settings.activeProvider,
                      onTap: () => showProviderPicker(context, ref),
                    ),
                  ),
                IconButton(
                  tooltip: 'Search',
                  icon: Icon(Icons.search),
                  onPressed: () => context.go('/search'),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
            home.when(
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: Column(
                    children: [
                      MediaRowSkeleton(height: 240),
                      SizedBox(height: AppSpacing.xl),
                      MediaRowSkeleton(height: 240),
                    ],
                  ),
                ),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(
                  title: 'The catalogue could not be loaded',
                  message: '$error',
                  onRetry: () => ref
                      .read(homeControllerProvider(activeProvider).notifier)
                      .refresh(),
                ),
              ),
              data: (state) {
                if (state.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      title: 'Nothing to show yet',
                      message:
                          'Snigea could not reach any provider. Check your '
                          'connection and the provider settings.',
                      icon: Icons.cloud_off_outlined,
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildListDelegate([
                    if (state.hint != null) _HintCard(message: state.hint!),
                    if (state.continueWatching.isNotEmpty &&
                        (settings?.showContinueWatching ?? true))
                      _ContinueWatchingRow(entries: state.continueWatching),
                    for (final section in state.sections)
                      MediaRow(
                        title: section.title,
                        subtitle: section.subtitle,
                        items: section.items,
                        onOpen: (item) => context.push(
                          '/title?provider=${item.id.provider.cacheKey}'
                          '&id=${Uri.encodeComponent(item.id.value)}',
                        ),
                      ),
                    if (state.error != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          AppSpacing.xl,
                          AppSpacing.gutter,
                          AppSpacing.xxxl,
                        ),
                        child: Text(
                          'Some providers could not be reached:\n'
                          '${state.error}',
                          style: context.typography.bodySmall,
                        ),
                      )
                    else
                      const SizedBox(height: AppSpacing.xxxl),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The hint that is shown above the rows.
class _HintCard extends StatelessWidget {
  const _HintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: context.colors.highlight),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: context.typography.bodySmall)),
        ],
      ),
    );
  }
}

/// The row with the titles that can be continued.
class _ContinueWatchingRow extends StatelessWidget {
  const _ContinueWatchingRow({required this.entries});

  final List<ProgressEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Continue watching',
          subtitle: 'Pick up where you stopped',
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _ContinueCard(entry: entry);
            },
          ),
        ),
      ],
    );
  }
}

/// The card of a title that can be continued.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry});

  final ProgressEntry entry;

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining(entry);
    return SizedBox(
      width: 240,
      child: GestureDetector(
        onTap: () => context.push(
          '/player?provider=${entry.provider.cacheKey}'
          '&id=${Uri.encodeComponent(entry.subjectId)}'
          '&season=${entry.season}&episode=${entry.episode}'
          '&title=${Uri.encodeComponent(entry.title)}',
        ),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              height: 104,
              child: PosterImage(
                url: entry.posterUrl,
                width: 74,
                height: 104,
                borderRadius: AppSpacing.radiusSm,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.mediaType == MediaType.series &&
                            entry.season > 0 &&
                            entry.episode > 0
                        ? 'S${entry.season.toString().padLeft(2, '0')}'
                              'E${entry.episode.toString().padLeft(2, '0')}'
                        : 'Movie',
                    style: context.typography.caption,
                  ),
                  if (remaining != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(remaining, style: context.typography.caption),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: entry.fraction,
                      minHeight: 3,
                      backgroundColor: context.colors.surfaceHigh,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF4EA8FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _remaining(ProgressEntry entry) {
    final duration = entry.durationMs;
    if (duration == null || duration <= 0) return null;
    final left = duration - entry.positionMs;
    if (left <= 0) return null;
    final minutes = (left / 60000).ceil();
    if (minutes < 60) return '$minutes min left';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h left' : '$hours h $rest min left';
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SnigeaLogo(size: 26),
        const SizedBox(width: AppSpacing.sm),
        const Text(
          'SNIGEA',
          style: TextStyle(
            fontSize: 15,
            letterSpacing: 2.6,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
