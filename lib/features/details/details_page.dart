import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/models/release.dart';
import '../../data/repositories/library_repository.dart';
import '../library/library_page.dart';
import '../../state/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/images.dart';
import 'details_controller.dart';

/// The details of a movie or a series.
class DetailsPage extends ConsumerStatefulWidget {
  const DetailsPage({super.key, required this.provider, required this.id});

  final String provider;
  final String id;

  @override
  ConsumerState<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends ConsumerState<DetailsPage> {
  int _season = 0;
  int _episode = 0;
  bool _seasonResolved = false;

  ProviderKind get _providerKind =>
      ProviderKind.tryParse(widget.provider) ?? ProviderKind.moviebox;

  DetailsArguments get _arguments =>
      DetailsArguments(provider: _providerKind, id: widget.id);

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(detailsProvider(_arguments));
    final library = ref.watch(libraryRepositoryProvider);
    final watchlist = ref.watch(libraryEntriesProvider(SavedKind.watchlist));
    final favourites = ref.watch(libraryEntriesProvider(SavedKind.favourite));
    final inWatchlist =
        watchlist.value?.any((entry) => entry.subjectId == widget.id) ?? false;
    final isFavourite =
        favourites.value?.any((entry) => entry.subjectId == widget.id) ?? false;

    return Scaffold(
      body: details.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, _) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              Expanded(
                child: ErrorView(
                  title: 'The title could not be loaded',
                  message: '$error',
                  onRetry: () => ref.invalidate(detailsProvider(_arguments)),
                ),
              ),
            ],
          ),
        ),
        data: (media) {
          if (!_seasonResolved) {
            _seasonResolved = true;
            final firstSeason = media.seasons.isEmpty
                ? null
                : media.seasons.first;
            _season = firstSeason?.number ?? 0;
            _episode = firstSeason != null && firstSeason.episodes.isNotEmpty
                ? firstSeason.episodes.first.number
                : 0;
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 300,
                backgroundColor: context.colors.background,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Watchlist',
                    icon: Icon(
                      inWatchlist ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    color: inWatchlist ? context.colors.accent : null,
                    onPressed: () =>
                        _toggleSaved(library, media, SavedKind.watchlist),
                  ),
                  IconButton(
                    tooltip: 'Favourites',
                    icon: Icon(
                      isFavourite ? Icons.favorite : Icons.favorite_border,
                    ),
                    color: isFavourite ? context.colors.danger : null,
                    onPressed: () =>
                        _toggleSaved(library, media, SavedKind.favourite),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: BackdropImage(url: media.posterUrl, height: 300),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.lg,
                    AppSpacing.gutter,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.title,
                        style: context.typography.headlineMedium,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          if (media.year != null) MetaChip(label: media.year!),
                          if (media.imdbRating != null)
                            MetaChip(
                              label: media.imdbRating!,
                              icon: Icons.star_rounded,
                              emphasised: true,
                            ),
                          if (media.duration != null)
                            MetaChip(
                              label: media.duration!,
                              icon: Icons.schedule,
                            ),
                          MetaChip(
                            label: media.isSeries ? 'Series' : 'Movie',
                            icon: media.isSeries
                                ? Icons.tv_outlined
                                : Icons.movie_outlined,
                          ),
                          for (final genre in media.genres.take(4))
                            MetaChip(label: genre),
                        ],
                      ),
                      if (media.director != null ||
                          media.stars != null ||
                          media.audios != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _MetadataBlock(media: media),
                      ],
                      if (media.description != null &&
                          media.description!.isNotEmpty) ...[
                        SizedBox(height: AppSpacing.lg),
                        Text(
                          media.description!,
                          style: context.typography.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      _PlayButton(media: media),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
              if (media.isSeries)
                SliverToBoxAdapter(
                  child: _SeasonSelector(
                    media: media,
                    selectedSeason: _season,
                    selectedEpisode: _episode,
                    onSelect: (season, episode) {
                      setState(() {
                        _season = season;
                        _episode = episode;
                      });
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: _SourceSection(
                  provider: _providerKind,
                  id: widget.id,
                  media: media,
                  season: media.isSeries ? _season : 0,
                  episode: media.isSeries ? _episode : 0,
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleSaved(
    LibraryRepository library,
    MediaDetails media,
    SavedKind kind,
  ) async {
    final added = await library.toggle(
      LibraryEntry(
        kind: kind,
        provider: media.id.provider,
        subjectId: media.id.value,
        title: media.title,
        mediaType: media.mediaType,
        posterUrl: media.posterUrl,
        year: media.year,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '${kind == SavedKind.favourite ? 'Added to' : 'Added to the'} '
                    '${kind == SavedKind.favourite ? 'favourites' : 'watchlist'}'
              : 'Removed from '
                    '${kind == SavedKind.favourite ? 'favourites' : 'watchlist'}',
        ),
      ),
    );
  }
}

class _MetadataBlock extends StatelessWidget {
  const _MetadataBlock({required this.media});

  final MediaDetails media;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (media.director != null)
          _MetadataRow(label: 'Director', value: media.director!),
        if (media.stars != null)
          _MetadataRow(label: 'Cast', value: media.stars!),
        if (media.audios != null)
          _MetadataRow(label: 'Audio', value: media.audios!),
        if (media.prints != null)
          _MetadataRow(label: 'Prints', value: media.prints!),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(label, style: context.typography.caption),
          ),
          Expanded(child: Text(value, style: context.typography.bodySmall)),
        ],
      ),
    );
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.media});

  final MediaDetails media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(
              '/player?provider=${media.id.provider.cacheKey}'
              '&id=${Uri.encodeComponent(media.id.value)}'
              '&season=${media.isSeries ? 1 : 0}'
              '&episode=${media.isSeries ? 1 : 0}'
              '&title=${Uri.encodeComponent(media.title)}',
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play'),
          ),
        ),
      ],
    );
  }
}

class _SeasonSelector extends StatelessWidget {
  const _SeasonSelector({
    required this.media,
    required this.selectedSeason,
    required this.selectedEpisode,
    required this.onSelect,
  });

  final MediaDetails media;
  final int selectedSeason;
  final int selectedEpisode;
  final void Function(int season, int episode) onSelect;

  @override
  Widget build(BuildContext context) {
    if (media.seasons.isEmpty) return const SizedBox.shrink();
    final season = media.seasons.firstWhere(
      (candidate) => candidate.number == selectedSeason,
      orElse: () => media.seasons.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Episodes', subtitle: 'Season $selectedSeason'),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            itemCount: media.seasons.length,
            separatorBuilder: (_, _) => SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = media.seasons[index];
              final selected = item.number == selectedSeason;
              return ChoiceChip(
                label: Text('Season ${item.number}'),
                selected: selected,
                onSelected: (_) {
                  final firstEpisode = item.episodes.isEmpty
                      ? 1
                      : item.episodes.first.number;
                  onSelect(item.number, firstEpisode);
                },
                selectedColor: context.colors.accent.withValues(alpha: 0.2),
                labelStyle: context.typography.caption.copyWith(
                  color: selected
                      ? context.colors.accent
                      : context.colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final episode in season.episodes)
          _EpisodeTile(
            episode: episode,
            selected: episode.number == selectedEpisode,
            onTap: () => onSelect(selectedSeason, episode.number),
          ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.selected,
    required this.onTap,
  });

  final Episode episode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.accent.withValues(alpha: 0.1)
              : context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected ? context.colors.accent : context.colors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                episode.code,
                style: context.typography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                episode.title ?? 'Episode ${episode.number}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodyMedium.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.play_circle_outline,
              size: 20,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceSection extends ConsumerStatefulWidget {
  const _SourceSection({
    required this.provider,
    required this.id,
    required this.media,
    required this.season,
    required this.episode,
  });

  final ProviderKind provider;
  final String id;
  final MediaDetails media;
  final int season;
  final int episode;

  @override
  ConsumerState<_SourceSection> createState() => _SourceSectionState();
}

class _SourceSectionState extends ConsumerState<_SourceSection> {
  /// The selected audio track, `null` means that every track is listed.
  String? _language;

  @override
  Widget build(BuildContext context) {
    final query = ReleaseQuery(
      provider: widget.provider,
      id: widget.id,
      season: widget.season,
      episode: widget.episode,
    );
    final releases = ref.watch(releasesProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Sources',
          subtitle: 'Pick the quality and the audio track you want to use',
        ),
        releases.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => _NoSourceNotice(
            message: _sourceHint(query.provider, '$error'),
            onRetry: () => ref.invalidate(releasesProvider(query)),
          ),
          data: (items) {
            final languages = <String>{};
            for (final release in items) {
              final language = release.language;
              if (language != null && language.trim().isNotEmpty) {
                languages.add(language);
              }
            }
            final sorted = languages.toList()..sort();
            final filtered = _language == null
                ? items
                : items
                      .where((release) => release.language == _language)
                      .toList();

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sorted.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _LanguageChip(
                            label: 'All audio',
                            selected: _language == null,
                            onTap: () => setState(() => _language = null),
                          ),
                          for (final language in sorted)
                            _LanguageChip(
                              label: language,
                              selected: _language == language,
                              onTap: () => setState(() => _language = language),
                            ),
                        ],
                      ),
                    ),
                  for (final release in filtered)
                    _SourceTile(
                      release: release,
                      media: widget.media,
                      season: widget.season,
                      episode: widget.episode,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The chip that selects the audio track of the sources.
class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.accent.withValues(alpha: 0.16)
              : context.colors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected ? context.colors.accent : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: context.typography.caption.copyWith(
            color: selected
                ? context.colors.accent
                : context.colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The explanation that is shown when a title has no playable source.
String _sourceHint(ProviderKind provider, String error) {
  if (provider == ProviderKind.addons) {
    return 'The installed addons only provide catalogues. Add a stream addon '
        'in the settings to play this title.\n\n$error';
  }
  return error;
}

/// The notice that is shown when a title has no playable source.
class _NoSourceNotice extends StatelessWidget {
  const _NoSourceNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: Color(0xFFF0B429),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'No playable source',
                  style: context.typography.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: context.typography.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try again'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/search'),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search another entry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({
    required this.release,
    required this.media,
    required this.season,
    required this.episode,
  });

  final Release release;
  final MediaDetails media;
  final int season;
  final int episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadService = ref.watch(downloadServiceProvider);
    final metadata = [
      if (release.quality != null) release.quality!,
      if (release.codec != null) release.codec!,
      if (release.language != null) release.language!,
    ];

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.colors.border),
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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  children: [
                    for (final item in metadata) MetaChip(label: item),
                    MetaChip(label: release.sourceLabel),
                    if (release.sizeBytes != null)
                      MetaChip(label: _formatSize(release.sizeBytes!)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          IconButton(
            tooltip: 'Download',
            icon: Icon(Icons.download_outlined),
            onPressed: downloadService.isSupported
                ? () async {
                    final task = await downloadService.enqueue(
                      release: release,
                      details: media,
                      season: season,
                      episode: episode,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          task == null
                              ? 'The download could not be started.'
                              : 'Download queued: ${task.fileName}',
                        ),
                      ),
                    );
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Play',
            icon: Icon(Icons.play_circle_outline),
            onPressed: () => context.push(
              '/player?provider=${media.id.provider.cacheKey}'
              '&id=${Uri.encodeComponent(media.id.value)}'
              '&season=$season&episode=$episode'
              '&title=${Uri.encodeComponent(media.title)}',
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
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
