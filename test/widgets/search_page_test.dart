import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/theme/app_theme.dart';
import 'package:snigea/data/database/app_database.dart';
import 'package:snigea/data/models/app_settings.dart';
import 'package:snigea/data/models/media.dart';
import 'package:snigea/data/models/provider_kind.dart';
import 'package:snigea/features/search/search_page.dart';
import 'package:snigea/providers/content_provider.dart';
import 'package:snigea/state/app_providers.dart';

/// A provider that answers with a fixed catalogue.
class _FakeProvider implements ContentProvider {
  _FakeProvider(this.items);

  final List<CatalogItem> items;
  int searchCount = 0;

  @override
  ProviderKind get id => ProviderKind.moviebox;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();

  @override
  Future<List<CatalogItem>> search(String query, {int page = 1}) async {
    searchCount++;
    return items;
  }

  @override
  Future<MediaDetails> details(String id) async => throw UnimplementedError();
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('the search page shows the recent searches', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(theme: AppTheme.dark(), home: const SearchPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search for something'), findsOneWidget);
  });

  testWidgets('typing searches the provider and shows the results', (
    tester,
  ) async {
    final provider = _FakeProvider([
      const CatalogItem(
        id: ProviderMediaId(provider: ProviderKind.moviebox, value: '1'),
        title: 'Inception',
        mediaType: MediaType.movie,
        year: '2010',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          providerRegistryProvider.overrideWithValue({
            ProviderKind.moviebox: provider,
          }),
          settingsProvider.overrideWith(() => _FakeSettingsController()),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const SearchPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Inception');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(provider.searchCount, greaterThan(0));
    expect(find.text('Inception'), findsWidgets);
  });
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => const AppSettings();
}
