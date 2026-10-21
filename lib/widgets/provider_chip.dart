import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';
import '../data/models/provider_kind.dart';
import '../state/app_providers.dart';

/// The chip that shows the active provider.
class ProviderChip extends StatelessWidget {
  const ProviderChip({
    super.key,
    required this.provider,
    required this.onTap,
    this.compact = false,
  });

  final ProviderKind provider;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dns_outlined,
              size: 14,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              provider.label,
              style: context.typography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the sheet that selects the active provider.
Future<void> showProviderPicker(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider).value;
  if (settings == null) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surfaceElevated,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Active provider',
              style: context.typography.titleMedium,
            ),
          ),
          RadioGroup<ProviderKind>(
            groupValue: settings.activeProvider,
            onChanged: (value) {
              if (value == null) return;
              ref.read(settingsProvider.notifier).setActiveProvider(value);
              Navigator.of(context).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final provider in ProviderKind.values)
                  RadioListTile<ProviderKind>(
                    value: provider,
                    title: Text(provider.label),
                    subtitle: settings.enabledProviders.contains(provider)
                        ? null
                        : Text(
                            'Disabled in the provider settings',
                            style: context.typography.caption,
                          ),
                    activeColor: context.colors.accent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
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
