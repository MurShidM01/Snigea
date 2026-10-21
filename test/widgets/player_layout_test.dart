import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/data/database/app_database.dart';
import 'package:snigea/features/player/player_page.dart';
import 'package:snigea/state/app_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('the player screen builds its layout without an error', (
    tester,
  ) async {
    // The media engine needs libmpv, which the test host usually does not
    // provide. The controller reports the failure through the error overlay,
    // so the layout is still exercised.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
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
    // The controls hide themselves after three seconds.
    await tester.pump(const Duration(seconds: 4));

    // A sliver inside a box widget would break the whole page.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the player screen shows the title of the media', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          home: PlayerPage(
            provider: 'moviebox',
            subjectId: '1',
            season: 0,
            episode: 0,
            title: 'A Movie Title',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('A Movie Title'), findsOneWidget);
  });
}
