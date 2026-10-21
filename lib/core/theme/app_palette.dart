import 'package:flutter/material.dart';

import 'app_typography.dart';

/// The semantic colour tokens of Snigea.
///
/// The palette is registered as a [ThemeExtension], therefore every widget
/// resolves the colours of the active theme instead of hard coding them.
/// The dark palette follows the zinc scale, the light palette the slate
/// scale, which keeps the flat, high contrast look of a modern web app.
@immutable
class SnigeaPalette extends ThemeExtension<SnigeaPalette> {
  const SnigeaPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHigh,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.highlight,
    required this.success,
    required this.danger,
    required this.warning,
    required this.scrim,
  });

  /// The canvas of the application.
  final Color background;

  /// The app bar and navigation surface.
  final Color surface;

  /// Cards and list tiles.
  final Color surfaceElevated;

  /// Inputs, chips and pills.
  final Color surfaceHigh;

  /// Hairline borders.
  final Color border;

  /// Borders of focused or selected elements.
  final Color borderStrong;

  /// Primary text.
  final Color textPrimary;

  /// Secondary text.
  final Color textSecondary;

  /// Tertiary and disabled text.
  final Color textTertiary;

  /// The interactive accent.
  final Color accent;

  /// A soft accent background.
  final Color accentSoft;

  /// Ratings and progress.
  final Color highlight;

  /// Positive state.
  final Color success;

  /// Destructive state.
  final Color danger;

  /// Warning state.
  final Color warning;

  /// Scrim over posters and backdrops.
  final Color scrim;

  /// The dark palette.
  static const SnigeaPalette dark = SnigeaPalette(
    background: Color(0xFF09090B),
    surface: Color(0xFF111113),
    surfaceElevated: Color(0xFF17171A),
    surfaceHigh: Color(0xFF232327),
    border: Color(0xFF27272A),
    borderStrong: Color(0xFF3F3F46),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textTertiary: Color(0xFF71717A),
    accent: Color(0xFF3B82F6),
    accentSoft: Color(0x1F3B82F6),
    highlight: Color(0xFFF59E0B),
    success: Color(0xFF22C55E),
    danger: Color(0xFFEF4444),
    warning: Color(0xFFF97316),
    scrim: Color(0xFF09090B),
  );

  /// The light palette.
  static const SnigeaPalette light = SnigeaPalette(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF94A3B8),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0x1F2563EB),
    highlight: Color(0xFFD97706),
    success: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    warning: Color(0xFFEA580C),
    scrim: Color(0xFF0F172A),
  );

  @override
  SnigeaPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHigh,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentSoft,
    Color? highlight,
    Color? success,
    Color? danger,
    Color? warning,
    Color? scrim,
  }) => SnigeaPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    highlight: highlight ?? this.highlight,
    success: success ?? this.success,
    danger: danger ?? this.danger,
    warning: warning ?? this.warning,
    scrim: scrim ?? this.scrim,
  );

  @override
  SnigeaPalette lerp(covariant SnigeaPalette? other, double t) {
    if (other == null) return this;
    return SnigeaPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Convenience accessors for the palette and the typography.
extension SnigeaThemeContext on BuildContext {
  /// The semantic colours of the active theme.
  SnigeaPalette get colors =>
      Theme.of(this).extension<SnigeaPalette>() ?? SnigeaPalette.dark;

  /// The typography of the active theme.
  AppTypography get typography => AppTypography(colors);
}
