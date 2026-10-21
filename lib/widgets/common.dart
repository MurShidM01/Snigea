import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';
import 'images.dart';

/// A small rounded label used for metadata such as quality or year.
class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.label,
    this.icon,
    this.emphasised = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: emphasised
            ? context.colors.accent.withValues(alpha: 0.16)
            : context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: emphasised ? context.colors.accent : context.colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: emphasised
                  ? context.colors.accent
                  : context.colors.textSecondary,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.typography.caption.copyWith(
              color: emphasised
                  ? context.colors.accent
                  : context.colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The rating badge shown on top of a poster.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.highlight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        rating,
        style: context.typography.caption.copyWith(
          color: const Color(0xFF231A02),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// A section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xl,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.typography.titleLarge),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(subtitle!, style: context.typography.bodySmall),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// A full width error state with a retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(icon, color: context.colors.textSecondary),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: context.typography.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: context.typography.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A full width empty state.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(icon, color: context.colors.textSecondary),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: context.typography.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: context.typography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A skeleton placeholder for a catalogue tile.
class MediaCardSkeleton extends StatelessWidget {
  const MediaCardSkeleton({super.key, this.width = 140});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ShimmerBox(borderRadius: AppSpacing.radiusMd),
          ),
          const SizedBox(height: AppSpacing.sm),
          ShimmerBox(height: 11, width: width * 0.85),
          const SizedBox(height: AppSpacing.xs),
          ShimmerBox(height: 9, width: width * 0.5),
        ],
      ),
    );
  }
}

/// A skeleton placeholder for a list row.
class MediaRowSkeleton extends StatelessWidget {
  const MediaRowSkeleton({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, _) => const MediaCardSkeleton(width: 130),
      ),
    );
  }
}
