/// Shared user agent strings.
///
/// The values are identical to the reference implementation so that providers
/// that validate the client continue to behave the same way.
abstract final class UserAgents {
  /// A plain desktop browser agent used for HTML scraping providers.
  static const String browser =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// The app agent used for binary fetches (posters, subtitles).
  static const String app = 'Snigea/1.0 (Flutter)';

  /// The agent used for the Stremio addon client.
  static const String addon = 'Snigea/1.0 (Addon-Client)';
}
