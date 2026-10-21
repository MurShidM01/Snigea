import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/provider_kind.dart';
import '../../providers/addons/addon_client.dart';
import '../../providers/addons/addon_models.dart';
import '../../state/app_providers.dart';
import '../../widgets/common.dart';

/// The settings screen.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final addons = ref.watch(addonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings == null
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.only(bottom: AppSpacing.xxxl),
              children: [
                SectionHeader(
                  title: 'Playback',
                  subtitle: 'How Snigea behaves while you watch',
                ),
                _SwitchTile(
                  title: 'Subtitles',
                  subtitle: 'Offer the subtitle tracks the provider provides',
                  value: settings.subtitlesEnabled,
                  onChanged: (value) =>
                      _update(ref, settings.copyWith(subtitlesEnabled: value)),
                ),
                _SwitchTile(
                  title: 'Autoplay next episode',
                  subtitle: 'Start the next episode automatically',
                  value: settings.autoPlayNextEpisode,
                  onChanged: (value) => _update(
                    ref,
                    settings.copyWith(autoPlayNextEpisode: value),
                  ),
                ),
                _SwitchTile(
                  title: 'Prefer the highest quality',
                  subtitle: 'Select the best available source by default',
                  value: settings.preferHighestQuality,
                  onChanged: (value) => _update(
                    ref,
                    settings.copyWith(preferHighestQuality: value),
                  ),
                ),
                _SwitchTile(
                  title: 'Show continue watching',
                  subtitle:
                      'Display the continue watching row on the home screen',
                  value: settings.showContinueWatching,
                  onChanged: (value) => _update(
                    ref,
                    settings.copyWith(showContinueWatching: value),
                  ),
                ),
                ListTile(
                  title: const Text('Default playback speed'),
                  subtitle: Text(
                    '${settings.playbackSpeed.toStringAsFixed(2)}x',
                  ),
                  trailing: SizedBox(
                    width: 160,
                    child: Slider(
                      value: settings.playbackSpeed,
                      min: 0.5,
                      max: 2,
                      divisions: 15,
                      onChanged: (value) =>
                          _update(ref, settings.copyWith(playbackSpeed: value)),
                    ),
                  ),
                ),
                SectionHeader(
                  title: 'Appearance',
                  subtitle: 'Pick the theme Snigea should use',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.lg,
                  ),
                  child: SegmentedButton<SnigeaThemeMode>(
                    segments: [
                      for (final mode in SnigeaThemeMode.values)
                        ButtonSegment<SnigeaThemeMode>(
                          value: mode,
                          label: Text(mode.label),
                        ),
                    ],
                    selected: {settings.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => _update(
                      ref,
                      settings.copyWith(themeMode: selection.first),
                    ),
                  ),
                ),
                SectionHeader(
                  title: 'Providers',
                  subtitle: 'Choose which sources Snigea is allowed to use',
                ),
                for (final provider in ProviderKind.values)
                  _SwitchTile(
                    title: provider.label,
                    subtitle: _providerSubtitle(provider),
                    value: settings.enabledProviders.contains(provider),
                    onChanged: (_) => ref
                        .read(settingsProvider.notifier)
                        .toggleProvider(provider),
                  ),
                SectionHeader(
                  title: 'Stremio addons',
                  subtitle: 'Add community catalogues and stream providers',
                ),
                addons.when(
                  loading: () => Padding(
                    padding: EdgeInsets.all(AppSpacing.gutter),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Padding(
                    padding: EdgeInsets.all(AppSpacing.gutter),
                    child: Text('$error', style: context.typography.bodySmall),
                  ),
                  data: (items) => Column(
                    children: [
                      for (final addon in items) _AddonTile(addon: addon),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.gutter),
                        child: OutlinedButton.icon(
                          onPressed: () => _installAddon(context, ref),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add an addon'),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionHeader(title: 'Storage'),
                ListTile(
                  leading: Icon(Icons.cleaning_services_outlined),
                  title: Text('Clear the metadata cache'),
                  subtitle: Text(
                    'Removes the cached provider responses. Favourites, '
                    'history and downloads are kept.',
                  ),
                  onTap: () async {
                    await ref.read(catalogServiceProvider).prune();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('The cache was cleaned')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Remove partial downloads'),
                  subtitle: Text(
                    'Deletes the incomplete files of interrupted downloads.',
                  ),
                  onTap: () async {
                    final removed = await ref
                        .read(downloadServiceProvider)
                        .cleanupPartials();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$removed partial file(s) removed'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Clear the search history'),
                  onTap: () =>
                      ref.read(searchHistoryRepositoryProvider).clear(),
                ),
                const SectionHeader(title: 'About'),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Snigea'),
                  subtitle: Text(
                    'A cross-platform client for the MovieBox, 4KHDHub, '
                    'Dramachi, CircleFTP, DhakaFlix and Stremio addon '
                    'providers. Everything is stored locally on this device.',
                  ),
                ),
              ],
            ),
    );
  }

  String _providerSubtitle(ProviderKind provider) {
    switch (provider) {
      case ProviderKind.moviebox:
        return 'Movies, series, subtitles and multi quality streams';
      case ProviderKind.fourkhdhub:
        return 'High bitrate releases with fast CDN mirrors';
      case ProviderKind.dramachi:
        return 'Asian dramas and series';
      case ProviderKind.bdixCircleFtp:
        return 'Requires a BDIX network';
      case ProviderKind.bdixDhakaFlix:
        return 'Requires a BDIX network';
      case ProviderKind.addons:
        return 'Community Stremio catalogues and streams';
    }
  }

  void _update(WidgetRef ref, AppSettings settings) {
    ref.read(settingsProvider.notifier).saveSettings(settings);
  }

  Future<void> _installAddon(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: 'https://v3-cinemeta.strem.io/manifest.json',
    );
    final address = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add an addon'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/manifest.json',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (address == null || address.isEmpty) return;

    try {
      await ref.read(addonsProvider.notifier).install(address);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('The addon was installed')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: context.typography.bodyLarge),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: context.typography.caption),
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      activeThumbColor: context.colors.accent,
    );
  }
}

class _AddonTile extends ConsumerWidget {
  const _AddonTile({required this.addon});

  final InstalledAddon addon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = addon.name;
    final enabled = addon.enabled;
    final provides = <String>[
      if (addon.providesCatalog) 'catalogue',
      if (addon.providesMeta) 'metadata',
      if (addon.providesStream) 'streams',
    ];

    return ListTile(
      leading: Icon(Icons.extension_outlined),
      title: Text(name, style: context.typography.bodyLarge),
      subtitle: Text(
        provides.isEmpty ? 'No resources' : provides.join(', '),
        style: context.typography.caption,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: enabled,
            onChanged: (_) => ref.read(addonsProvider.notifier).toggle(addon),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => ref.read(addonsProvider.notifier).uninstall(addon),
          ),
        ],
      ),
    );
  }
}

/// Exposes the addon URL normalisation for the settings screen.
String normaliseAddonUrl(String raw) => AddonClient.normalizeManifestUrl(raw);
