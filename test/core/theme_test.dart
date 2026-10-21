import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/theme/app_palette.dart';
import 'package:snigea/core/theme/app_theme.dart';
import 'package:snigea/data/models/app_settings.dart';

void main() {
  group('SnigeaPalette', () {
    testWidgets('the dark and the light theme expose their own tokens', (
      tester,
    ) async {
      late SnigeaPalette dark;
      late SnigeaPalette light;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              dark = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              light = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );
      // The theme change is animated, so the new tokens are only visible
      // after the transition has finished.
      await tester.pumpAndSettle();

      expect(dark.background, isNot(light.background));
      expect(dark.textPrimary, isNot(light.textPrimary));
      expect(dark.accent, isNot(light.accent));
      expect(dark.surfaceElevated, isNot(light.surfaceElevated));

      // The light theme has a bright canvas and dark text, the dark theme
      // the other way round.
      expect(
        light.background.computeLuminance(),
        greaterThan(dark.background.computeLuminance()),
      );
      expect(
        light.textPrimary.computeLuminance(),
        lessThan(dark.textPrimary.computeLuminance()),
      );
    });

    test('the palette is registered as a theme extension', () {
      final theme = AppTheme.dark();
      expect(theme.extension<SnigeaPalette>(), isNotNull);
      expect(theme.extension<SnigeaPalette>(), SnigeaPalette.dark);
    });

    test('neither theme uses elevation or shadows', () {
      for (final theme in [AppTheme.dark(), AppTheme.light()]) {
        expect(theme.shadowColor, Colors.transparent);
        expect(theme.cardTheme.elevation, 0);
        expect(theme.appBarTheme.elevation, 0);
        expect(theme.navigationBarTheme.elevation, 0);
      }
    });

    test('the navigation bar does not paint a pill behind the active icon', () {
      for (final theme in [AppTheme.dark(), AppTheme.light()]) {
        expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);
      }
    });
  });

  group('SnigeaThemeMode', () {
    test('maps the stored value to a Flutter theme mode', () {
      expect(SnigeaThemeMode.system.themeMode, ThemeMode.system);
      expect(SnigeaThemeMode.light.themeMode, ThemeMode.light);
      expect(SnigeaThemeMode.dark.themeMode, ThemeMode.dark);
    });

    test('parses an unknown value as system', () {
      expect(SnigeaThemeMode.fromWire('unknown'), SnigeaThemeMode.system);
      expect(SnigeaThemeMode.fromWire('dark'), SnigeaThemeMode.dark);
    });

    test('is stored in the preferences', () {
      const settings = AppSettings(themeMode: SnigeaThemeMode.light);
      final decoded = AppSettings.decode(settings.encode());
      expect(decoded.themeMode, SnigeaThemeMode.light);
    });
  });
}
