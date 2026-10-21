import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/theme/app_theme.dart';
import 'package:snigea/features/settings/credits_dialog.dart';

void main() {
  testWidgets('the credits name the reference project and the licence', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => CreditsDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Credits'), findsOneWidget);
    expect(find.text('MovieBox-Tui'), findsOneWidget);
    expect(find.text('The providers'), findsOneWidget);
    expect(find.text('Licence'), findsOneWidget);
    expect(find.textContaining('Apache License 2.0'), findsOneWidget);
    expect(find.textContaining('MIT licence'), findsOneWidget);
  });

  testWidgets('the credits can be closed again', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => CreditsDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CreditsDialog), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(CreditsDialog), findsNothing);
  });
}
