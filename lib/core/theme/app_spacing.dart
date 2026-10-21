/// Spacing scale used consistently across the app.
///
/// Every value is a multiple of 4 so that rhythm stays predictable on phone,
/// tablet and desktop layouts.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter.
  static const double gutter = 20;

  /// Minimum touch target.
  static const double tapTarget = 44;

  /// Maximum content width for very wide desktop windows.
  static const double contentMaxWidth = 1440;

  /// Corner radius for cards and media tiles (rounded-xl).
  static const double radiusLg = 12;

  /// Corner radius for buttons and chips (rounded-lg).
  static const double radiusMd = 8;

  /// Corner radius for small pills (rounded-md).
  static const double radiusSm = 6;
}
