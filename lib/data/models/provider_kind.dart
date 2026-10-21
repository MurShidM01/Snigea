/// The set of content providers Snigea talks to.
///
/// The identifiers mirror the reference MovieBox-TUI provider kinds so that
/// cached payloads, database rows and provider configuration stay compatible
/// with the upstream naming.
enum ProviderKind {
  moviebox('moviebox', 'MovieBox'),
  fourkhdhub('fourkhdhub', '4KHDHub'),
  dramachi('dramachi', 'Dramachi'),
  bdixCircleFtp('bdix_circleftp', 'CircleFTP'),
  bdixDhakaFlix('bdix_dhakaflix', 'DhakaFlix'),
  addons('addons', 'Addons');

  const ProviderKind(this.cacheKey, this.label);

  /// Stable key used for persistence and configuration.
  final String cacheKey;

  /// Human readable provider name.
  final String label;

  /// Providers that are reachable by default in the reference implementation.
  static const List<ProviderKind> enabledByDefault = [
    ProviderKind.moviebox,
    ProviderKind.fourkhdhub,
    ProviderKind.dramachi,
  ];

  /// Providers that require a local BDIX network.
  bool get isBdix =>
      this == ProviderKind.bdixCircleFtp || this == ProviderKind.bdixDhakaFlix;

  /// Parses a persisted provider key.
  static ProviderKind? tryParse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final provider in ProviderKind.values) {
      if (provider.cacheKey == normalized) return provider;
    }
    switch (normalized) {
      case '4khdhub':
      case 'four_k_hd_hub':
        return ProviderKind.fourkhdhub;
      case 'bdix_circle_ftp':
      case 'circleftp (bdix)':
        return ProviderKind.bdixCircleFtp;
      case 'bdix_dhaka_flix':
      case 'dhakaflix (bdix)':
        return ProviderKind.bdixDhakaFlix;
      case 'addon':
        return ProviderKind.addons;
      default:
        return null;
    }
  }
}
