import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/repositories/settings_repository.dart';
import '../../providers/moviebox/moviebox_parser.dart';
import '../../state/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/provider_chip.dart';
import '../../widgets/media_card.dart';

/// The state of the search screen.
class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.error,
    this.hasSearched = false,
  });

  final String query;
  final List<CatalogItem> results;
  final bool isSearching;
  final String? error;
  final bool hasSearched;

  SearchState copyWith({
    String? query,
    List<CatalogItem>? results,
    bool? isSearching,
    String? error,
    bool? hasSearched,
  }) => SearchState(
    query: query ?? this.query,
    results: results ?? this.results,
    isSearching: isSearching ?? this.isSearching,
    error: error,
    hasSearched: hasSearched ?? this.hasSearched,
  );
}

/// Drives the search screen.
class SearchController extends AsyncNotifier<SearchState> {
  static const Duration _debounce = Duration(milliseconds: 350);

  Timer? _timer;
  int _requestId = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SearchState();
  }

  /// Updates the query and schedules a debounced search.
  void queryChanged(String query) {
    final current = state.value ?? const SearchState();
    state = AsyncData(current.copyWith(query: query));
    _timer?.cancel();
    if (query.trim().isEmpty) {
      state = AsyncData(const SearchState());
      return;
    }
    _timer = Timer(_debounce, () => _run(query));
  }

  /// Runs a search immediately.
  Future<void> searchNow(String query) async {
    _timer?.cancel();
    if (query.trim().isEmpty) return;
    await _run(query);
  }

  /// Searches the MovieBox homepage catalogue.
  ///
  /// The upstream search endpoint answers with "no content" when the visitor
  /// session is not allowed to use the search index. The homepage catalogue
  /// is still available and is used as a fallback.
  Future<List<CatalogItem>> _searchHomepage(String query) async {
    try {
      final client = ref.read(movieBoxClientProvider);
      final payload = await client.homepage('2', 1);
      final (items, _) = MovieBoxParser.homepageJsonToCatalog(payload);
      final needle = query.trim().toLowerCase();
      return items
          .where((item) => item.title.toLowerCase().contains(needle))
          .toList();
    } catch (error) {
      return const [];
    }
  }

  /// The provider that is used for the search.
  ///
  /// The active provider wins, but a disabled provider falls back to the
  /// first provider that the user enabled.
  ProviderKind _resolveProvider(AppSettings? settings) {
    final active = settings?.activeProvider ?? ProviderKind.moviebox;
    final enabled = settings?.enabledProviders ?? const <ProviderKind>{};
    if (enabled.isEmpty || enabled.contains(active)) return active;
    return enabled.first;
  }

  Future<void> _run(String query) async {
    final requestId = ++_requestId;
    final current = state.value ?? const SearchState();
    state = AsyncData(current.copyWith(isSearching: true, error: null));

    final settings = ref.read(settingsProvider).value;
    final provider = _resolveProvider(settings);
    final registry = ref.read(providerRegistryProvider);
    final contentProvider = registry[provider];
    if (contentProvider == null) {
      state = AsyncData(
        current.copyWith(
          isSearching: false,
          hasSearched: true,
          error: 'The provider ${provider.label} is not available.',
        ),
      );
      return;
    }

    try {
      var results = await contentProvider.search(query);
      if (results.isEmpty && provider == ProviderKind.moviebox) {
        // The upstream search sometimes answers with "no content" for a
        // visitor session. The homepage catalogue is still available, so the
        // query is answered from it.
        results = await _searchHomepage(query);
      }
      if (requestId != _requestId) return;
      await ref
          .read(searchHistoryRepositoryProvider)
          .record(query, provider, resultCount: results.length);
      state = AsyncData(
        current.copyWith(
          results: results,
          isSearching: false,
          hasSearched: true,
          error: null,
        ),
      );
    } catch (error) {
      if (requestId != _requestId) return;
      state = AsyncData(
        current.copyWith(
          isSearching: false,
          hasSearched: true,
          error: '$error',
        ),
      );
    }
  }
}

/// The search screen state.
final searchControllerProvider =
    AsyncNotifierProvider<SearchController, SearchState>(SearchController.new);

/// The recent search queries.
final searchHistoryProvider = FutureProvider<List<SearchHistoryEntry>>((ref) {
  return ref.watch(searchHistoryRepositoryProvider).recent();
});

/// The search screen.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search =
        ref.watch(searchControllerProvider).value ?? const SearchState();
    final history = ref.watch(searchHistoryProvider);
    final settings = ref.watch(settingsProvider).value;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.only(right: AppSpacing.lg),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            style: context.typography.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Search movies and series',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
            onChanged: (value) {
              ref.read(searchControllerProvider.notifier).queryChanged(value);
              setState(() {});
            },
            onSubmitted: (value) =>
                ref.read(searchControllerProvider.notifier).searchNow(value),
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                ref.read(searchControllerProvider.notifier).queryChanged('');
                setState(() {});
              },
            ),
          // The search follows the active provider, so the provider can be
          // changed right here.
          if (settings != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ProviderChip(
                provider: settings.activeProvider,
                compact: true,
                onTap: () => showProviderPicker(context, ref),
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _buildBody(context, search, history),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SearchState search,
    AsyncValue<List<SearchHistoryEntry>> history,
  ) {
    if (search.query.trim().isEmpty) {
      return history.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          title: 'The search history is unavailable',
          message: '$error',
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyView(
              title: 'Search for something',
              message:
                  'Snigea searches the provider that is active in the '
                  'settings. Switch providers at any time.',
              icon: Icons.search,
            );
          }
          return ListView(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              SectionHeader(title: 'Recent searches'),
              for (final entry in entries)
                ListTile(
                  leading: Icon(Icons.history, size: 20),
                  title: Text(entry.query, style: context.typography.bodyLarge),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => ref
                        .read(searchHistoryRepositoryProvider)
                        .remove(entry.query),
                  ),
                  onTap: () {
                    _controller.text = entry.query;
                    setState(() {});
                    ref
                        .read(searchControllerProvider.notifier)
                        .searchNow(entry.query);
                  },
                ),
            ],
          );
        },
      );
    }

    if (search.isSearching && search.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (search.error != null && search.results.isEmpty) {
      return ErrorView(
        title: 'The search failed',
        message: search.error!,
        onRetry: () =>
            ref.read(searchControllerProvider.notifier).searchNow(search.query),
      );
    }

    if (search.results.isEmpty && search.hasSearched) {
      return EmptyView(
        title: 'No results',
        message: 'Nothing matched "${search.query}".',
        icon: Icons.search_off,
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xxxl,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.52,
      ),
      itemCount: search.results.length,
      itemBuilder: (context, index) {
        final item = search.results[index];
        return MediaCard(
          item: item,
          width: double.infinity,
          onTap: () => context.push(
            '/title?provider=${item.id.provider.cacheKey}'
            '&id=${Uri.encodeComponent(item.id.value)}',
          ),
        );
      },
    );
  }
}
