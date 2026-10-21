import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/theme/app_theme.dart';
import 'package:snigea/data/models/media.dart';
import 'package:snigea/data/models/provider_kind.dart';
import 'package:snigea/widgets/media_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('renders the title, the year and the type', (tester) async {
    const item = CatalogItem(
      id: ProviderMediaId(provider: ProviderKind.moviebox, value: '1'),
      title: 'Inception',
      mediaType: MediaType.movie,
      year: '2010',
    );

    await tester.pumpWidget(wrap(const MediaCard(item: item, width: 150)));

    expect(find.text('Inception'), findsOneWidget);
    expect(find.text('2010'), findsOneWidget);
    expect(find.text('Movie'), findsOneWidget);
  });

  testWidgets('shows the season count of a series', (tester) async {
    const item = CatalogItem(
      id: ProviderMediaId(provider: ProviderKind.moviebox, value: '2'),
      title: 'Breaking Bad',
      mediaType: MediaType.series,
      year: '2008',
      seasonCount: 5,
    );

    await tester.pumpWidget(wrap(const MediaCard(item: item, width: 150)));

    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('5 seasons'), findsOneWidget);
  });

  testWidgets('reports taps', (tester) async {
    const item = CatalogItem(
      id: ProviderMediaId(provider: ProviderKind.moviebox, value: '1'),
      title: 'Inception',
      mediaType: MediaType.movie,
    );
    var tapped = false;

    await tester.pumpWidget(
      wrap(MediaCard(item: item, width: 150, onTap: () => tapped = true)),
    );

    await tester.tap(find.text('Inception'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('shows the playback progress', (tester) async {
    const item = CatalogItem(
      id: ProviderMediaId(provider: ProviderKind.moviebox, value: '1'),
      title: 'Inception',
      mediaType: MediaType.movie,
    );

    await tester.pumpWidget(
      wrap(const MediaCard(item: item, width: 150, progress: 0.4)),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.4, 0.001));
  });
}
