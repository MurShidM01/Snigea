import 'package:flutter/material.dart';

import 'app_palette.dart';

/// The typography scale of Snigea.
///
/// The scale is intentionally tight and high contrast: large titles with
/// negative tracking, and compact metadata labels with positive tracking.
/// The colours come from the active palette, so the type stays legible in
/// both the light and the dark theme.
@immutable
class AppTypography {
  const AppTypography(this.colors);

  /// The palette the type is rendered with.
  final SnigeaPalette colors;

  TextStyle get display => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 40,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    color: colors.textPrimary,
  );

  TextStyle get headlineLarge => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 30,
    height: 1.14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    color: colors.textPrimary,
  );

  TextStyle get headlineMedium => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 23,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: colors.textPrimary,
  );

  TextStyle get titleLarge => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 19,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: colors.textPrimary,
  );

  TextStyle get titleMedium => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: colors.textPrimary,
  );

  TextStyle get titleSmall => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: colors.textPrimary,
  );

  TextStyle get bodyLarge => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: colors.textPrimary,
  );

  TextStyle get bodyMedium => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: colors.textSecondary,
  );

  TextStyle get bodySmall => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12.5,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: colors.textSecondary,
  );

  /// Small uppercase label used for section eyebrows and metadata chips.
  TextStyle get label => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: colors.textTertiary,
  );

  TextStyle get caption => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 11.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: colors.textTertiary,
  );
}
