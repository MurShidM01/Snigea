import 'dart:convert';

import 'package:flutter/material.dart';

import 'provider_kind.dart';

/// The theme the user prefers.
enum SnigeaThemeMode {
  system('system', 'System'),
  light('light', 'Light'),
  dark('dark', 'Dark');

  const SnigeaThemeMode(this.wireName, this.label);

  /// The value that is stored in the database.
  final String wireName;

  /// The label that is shown in the settings.
  final String label;

  /// The Flutter theme mode.
  ThemeMode get themeMode => switch (this) {
    SnigeaThemeMode.system => ThemeMode.system,
    SnigeaThemeMode.light => ThemeMode.light,
    SnigeaThemeMode.dark => ThemeMode.dark,
  };

  /// Parses a stored value.
  static SnigeaThemeMode fromWire(String? value) =>
      SnigeaThemeMode.values.firstWhere(
        (mode) => mode.wireName == value,
        orElse: () => SnigeaThemeMode.system,
      );
}

/// The user preferences of the application.
class AppSettings {
  const AppSettings({
    this.activeProvider = ProviderKind.moviebox,
    this.enabledProviders = const {
      ProviderKind.moviebox,
      ProviderKind.fourkhdhub,
      ProviderKind.dramachi,
    },
    this.playbackSpeed = 1.0,
    this.subtitlesEnabled = true,
    this.autoPlayNextEpisode = true,
    this.preferHighestQuality = true,
    this.downloadDirectory,
    this.showContinueWatching = true,
    this.themeMode = SnigeaThemeMode.system,
  });

  /// The provider that is used when the user searches.
  final ProviderKind activeProvider;

  /// The providers that are enabled.
  final Set<ProviderKind> enabledProviders;

  /// The preferred playback speed.
  final double playbackSpeed;

  /// Whether subtitles are offered by default.
  final bool subtitlesEnabled;

  /// Whether the next episode starts automatically.
  final bool autoPlayNextEpisode;

  /// Whether the highest available quality is preselected.
  final bool preferHighestQuality;

  /// A custom download directory, if the user configured one.
  final String? downloadDirectory;

  /// Whether the continue watching row is shown on the home screen.
  final bool showContinueWatching;

  /// The preferred theme.
  final SnigeaThemeMode themeMode;

  /// A copy with the given fields replaced.
  AppSettings copyWith({
    ProviderKind? activeProvider,
    Set<ProviderKind>? enabledProviders,
    double? playbackSpeed,
    bool? subtitlesEnabled,
    bool? autoPlayNextEpisode,
    bool? preferHighestQuality,
    String? downloadDirectory,
    bool? showContinueWatching,
    SnigeaThemeMode? themeMode,
    bool clearDownloadDirectory = false,
  }) => AppSettings(
    activeProvider: activeProvider ?? this.activeProvider,
    enabledProviders: enabledProviders ?? this.enabledProviders,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
    autoPlayNextEpisode: autoPlayNextEpisode ?? this.autoPlayNextEpisode,
    preferHighestQuality: preferHighestQuality ?? this.preferHighestQuality,
    downloadDirectory: clearDownloadDirectory
        ? null
        : (downloadDirectory ?? this.downloadDirectory),
    showContinueWatching: showContinueWatching ?? this.showContinueWatching,
    themeMode: themeMode ?? this.themeMode,
  );

  /// Serialises the settings.
  String encode() => jsonEncode({
    'active_provider': activeProvider.cacheKey,
    'enabled_providers': enabledProviders
        .map((provider) => provider.cacheKey)
        .toList(),
    'playback_speed': playbackSpeed,
    'subtitles_enabled': subtitlesEnabled,
    'auto_play_next_episode': autoPlayNextEpisode,
    'prefer_highest_quality': preferHighestQuality,
    'download_directory': downloadDirectory,
    'show_continue_watching': showContinueWatching,
    'theme_mode': themeMode.wireName,
  });

  /// Restores the settings, falling back to the defaults.
  static AppSettings decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const AppSettings();
      final map = json.cast<String, Object?>();
      final provider =
          ProviderKind.tryParse(map['active_provider']?.toString() ?? '') ??
          ProviderKind.moviebox;
      final enabled = <ProviderKind>{};
      final rawProviders = map['enabled_providers'];
      if (rawProviders is List) {
        for (final entry in rawProviders) {
          final parsed = ProviderKind.tryParse(entry.toString());
          if (parsed != null) enabled.add(parsed);
        }
      }
      return AppSettings(
        activeProvider: provider,
        enabledProviders: enabled.isEmpty ? <ProviderKind>{provider} : enabled,
        playbackSpeed: (map['playback_speed'] as num?)?.toDouble() ?? 1.0,
        subtitlesEnabled: map['subtitles_enabled'] != false,
        autoPlayNextEpisode: map['auto_play_next_episode'] != false,
        preferHighestQuality: map['prefer_highest_quality'] != false,
        downloadDirectory: map['download_directory'] as String?,
        showContinueWatching: map['show_continue_watching'] != false,
        themeMode: SnigeaThemeMode.fromWire(map['theme_mode']?.toString()),
      );
    } on FormatException {
      return const AppSettings();
    }
  }
}
