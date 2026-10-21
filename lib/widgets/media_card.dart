import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';
import '../data/models/media.dart';
import 'common.dart';
import 'images.dart';

/// A poster tile used in the catalogue grids and rows.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.width = 150,
    this.rating,
    this.progress,
    this.watched = false,
    this.badge,
  });

  final CatalogItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final String? rating;

  /// The playback progress in percent, if the title was started.
  final double? progress;

  /// Whether the title has been watched completely.
  final bool watched;

  /// An optional label shown in the top left corner.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: context.colors.border),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: PosterImage(
                      url: item.posterUrl,
                      width: width,
                      borderRadius: AppSpacing.radiusMd,
                    ),
                  ),
                  if (rating != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: RatingBadge(rating: rating!),
                    ),
                  if (badge != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: MetaChip(label: badge!, emphasised: true),
                    ),
                  if (watched)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.colors.success,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Color(0xFF04140C),
                        ),
                      ),
                    ),
                  if (progress != null && progress! > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(AppSpacing.radiusMd),
                        ),
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: context.colors.surfaceHigh,
                          valueColor: AlwaysStoppedAnimation(
                            context.colors.accent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.typography.titleSmall,
            ),
            SizedBox(height: 2),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 2,
              children: [
                if (item.year != null)
                  Text(item.year!, style: context.typography.caption),
                if (item.isSeries)
                  Text(
                    item.seasonCount != null
                        ? '${item.seasonCount} seasons'
                        : 'Series',
                    style: context.typography.caption,
                  )
                else
                  Text('Movie', style: context.typography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of media cards.
class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.title,
    required this.items,
    this.onOpen,
    this.onLongPress,
    this.subtitle,
    this.aspectRatio = 2 / 3,
    this.cardWidth = 150,
    this.emptyMessage,
  });

  final String title;
  final String? subtitle;
  final List<CatalogItem> items;
  final void Function(CatalogItem item)? onOpen;
  final void Function(CatalogItem item)? onLongPress;
  final double aspectRatio;
  final double cardWidth;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (emptyMessage == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Text(emptyMessage!, style: context.typography.bodySmall),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        SizedBox(
          height: cardWidth / aspectRatio + 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return MediaCard(
                item: item,
                width: cardWidth,
                onTap: onOpen == null ? null : () => onOpen!(item),
                onLongPress: onLongPress == null
                    ? null
                    : () => onLongPress!(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
