import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';

/// The credits of the application.
///
/// The providers of Snigea were ported from an existing project and the
/// application builds on the packages of the Dart and the Flutter community.
/// This dialog names them, the complete list is in the CREDITS.md file of the
/// repository.
class CreditsDialog extends StatelessWidget {
  const CreditsDialog({super.key});

  /// Shows the credits of the application.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const CreditsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: context.colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Credits',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                shrinkWrap: true,
                children: const [
                  _CreditsEntry(
                    title: 'MovieBox-Tui',
                    subtitle:
                        'The terminal interface to find, download and stream '
                        'movies and series. The providers of Snigea, the '
                        'request signing, the parsing rules and the upstream '
                        'fixes were ported from it.',
                    url: 'https://github.com/mesamirh/MovieBox-Tui',
                  ),
                  _CreditsEntry(
                    title: 'The Dart and the Flutter community',
                    subtitle:
                        'Riverpod, go_router, Dio, Drift, media_kit, the '
                        'SQLite WebAssembly build and the packages of the '
                        'Dart team make this application possible.',
                    url: 'https://pub.dev/packages/flutter_riverpod',
                  ),
                  _CreditsEntry(
                    title: 'The providers',
                    subtitle:
                        'MovieBox, 4KHDHub, Dramachi, the BDIX mirrors and '
                        'the Stremio addons. Snigea hosts nothing, it plays '
                        'what they publish.',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Licence',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Snigea is dual licensed under the Apache License 2.0 and '
                    'the MIT licence, at your option. The third party '
                    'components keep their own licences.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single entry of the credits.
class _CreditsEntry extends StatelessWidget {
  const _CreditsEntry({required this.title, required this.subtitle, this.url});

  final String title;
  final String subtitle;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (url != null)
                Icon(Icons.open_in_new, size: 14, color: context.colors.accent),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
