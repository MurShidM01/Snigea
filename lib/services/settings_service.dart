import '../data/models/app_settings.dart';
import '../data/models/provider_kind.dart';
import '../data/repositories/settings_repository.dart';

/// Loads and stores the user preferences.
class SettingsService {
  SettingsService(this._repository, this._providerConfigs);

  static const String _settingsKey = 'app_settings';

  final SettingsRepository _repository;
  final ProviderConfigRepository _providerConfigs;

  /// Loads the current settings.
  Future<AppSettings> load() async {
    final raw = await _repository.read(_settingsKey);
    if (raw == null) return const AppSettings();
    return AppSettings.decode(raw);
  }

  /// Stores the settings.
  Future<void> save(AppSettings settings) =>
      _repository.write(_settingsKey, settings.encode());

  /// Loads the provider configuration.
  Future<Map<ProviderKind, ProviderSettings>> providerConfigs() =>
      _providerConfigs.all();

  /// Stores the provider configuration.
  Future<void> saveProviderConfig(ProviderSettings config) =>
      _providerConfigs.save(config);
}
