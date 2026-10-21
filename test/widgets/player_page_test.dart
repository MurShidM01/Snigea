import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:snigea/features/player/player_page.dart';

void main() {
  testWidgets('the player screen starts without a provider override', (
    tester,
  ) async {
    // The media engine needs libmpv. When the host does not provide it the
    // screen cannot be exercised here, so the test returns early instead of
    // leaving a half started engine behind.
    try {
      MediaKit.ensureInitialized();
    } on Exception {
      return;
    }

    // The player used to read its arguments from a provider that only the
    // screen itself could override. Because the controller lived in the root
    // container, the override never applied and the screen reported that the
    // arguments were missing. The arguments are now part of the provider key,
    // so the screen works on its own.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PlayerPage(
            provider: 'moviebox',
            subjectId: '1',
            season: 0,
            episode: 0,
            title: 'Test',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('player arguments'), findsNothing);
    expect(find.textContaining('must be overridden'), findsNothing);
  });
}
