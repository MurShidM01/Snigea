import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_utils.dart';
import '../../core/text/cleaners.dart';
import '../../data/models/media.dart';
import '../../data/models/provider_kind.dart';
import '../../data/repositories/progress_repository.dart';
import '../../providers/addons/addon_models.dart';
import '../../providers/addons/addon_provider.dart';
import '../../providers/moviebox/moviebox_parser.dart';
import '../../state/app_providers.dart';

/// A single row of the discovery screen.
class HomeSection {
  const HomeSection({
    required this.title,
    required this.items,
    this.subtitle,
    this.sourceLabel,
  });

  final String title;
  final String? subtitle;
  final List<CatalogItem> items;
  final String? sourceLabel;
}

/// The state of the discovery screen.
class HomeState {
  const HomeState({
    this.sections = const [],
    this.continueWatching = const [],
    this.error,
    this.hint,
  });

  final List<HomeSection> sections;
  final List<ProgressEntry> continueWatching;
  final String? error;

  /// An explanation that is shown above the rows.
  final String? hint;

  bool get isEmpty => sections.isEmpty && continueWatching.isEmpty;
}

/// Loads the content of the discovery screen.
class HomeController extends AsyncNotifier<HomeState> {
  HomeController(this.activeProvider);

  /// The provider whose catalogue is shown.
  final ProviderKind activeProvider;

  @override
  Future<HomeState> build() async {
    // The screen is keyed by the active provider, so switching the provider
    // loads the catalogue of the new provider right away.
    final settings = ref.read(settingsProvider).value;
    final enabledProviders =
        settings?.enabledProviders ??
        const <ProviderKind>{ProviderKind.moviebox};

    final progressRepository = ref.watch(progressRepositoryProvider);
    final continueWatching = await progressRepository.continueWatching();

    final sections = <HomeSection>[];
    final errors = <String>[];

    // The catalogue rows follow the active provider: every provider exposes
    // a different catalogue, so the row follows the selection of the user.
    if (enabledProviders.contains(activeProvider)) {
      try {
        sections.addAll(await _loadProviderSections(activeProvider));
      } catch (error) {
        errors.add('${activeProvider.label}: $error');
      }
    }

    return HomeState(
      sections: sections,
      continueWatching: continueWatching,
      error: errors.isEmpty ? null : errors.join('\n'),
      hint: _hintFor(activeProvider, sections),
    );
  }

  /// Reloads the discovery screen.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// The rows of the active provider.
  Future<List<HomeSection>> _loadProviderSections(ProviderKind provider) async {
    switch (provider) {
      case ProviderKind.moviebox:
        return _loadMovieBoxSections();
      case ProviderKind.fourkhdhub:
        return _loadFourKHdHubSections();
      case ProviderKind.dramachi:
        return _loadDramachiSections();
      case ProviderKind.addons:
        return _loadAddonCatalogs();
      case ProviderKind.bdixCircleFtp:
      case ProviderKind.bdixDhakaFlix:
        return const [];
    }
  }

  // ------------------------------------------------------------- MovieBox

  /// The rows of the MovieBox catalogue.
  ///
  /// The upstream homepage groups the titles in themed rows such as
  /// "Trending movies" or "Trending TV series"; every group with titles
  /// becomes a row of the screen.
  Future<List<HomeSection>> _loadMovieBoxSections() async {
    final client = ref.read(movieBoxClientProvider);
    final sections = <HomeSection>[];

    for (final tab in const ['1', '5']) {
      final payload = await client.homepage(tab, 1);
      for (final group in _movieBoxGroups(payload)) {
        if (sections.length >= 8) break;
        final items = group.items;
        if (items.isEmpty) continue;
        sections.add(
          HomeSection(
            title: group.title,
            subtitle: 'From MovieBox',
            items: items,
            sourceLabel: ProviderKind.moviebox.label,
          ),
        );
      }
    }
    return sections;
  }

  /// The titled groups of a MovieBox homepage payload.
  ///
  /// The upstream payload keeps the titles in several places: directly on the
  /// item, in the ranking list, in the banner and in the custom data. Every
  /// place that carries titles becomes a row of the screen.
  List<({String title, List<CatalogItem> items})> _movieBoxGroups(
    Object? payload,
  ) {
    final map = asMap(payload);
    final entries = asList(map?['items']) ?? const [];
    final result = <({String title, List<CatalogItem> items})>[];

    void collect(String? rawTitle, List<Object?> subjects) {
      if (rawTitle == null || rawTitle.trim().isEmpty) return;
      final items = <CatalogItem>[];
      final seen = <String>{};
      for (final subject in subjects) {
        final item = MovieBoxParser.subjectJsonToCatalogItem(subject);
        if (item == null) continue;
        if (!seen.add(item.id.value)) continue;
        items.add(item);
      }
      if (items.isEmpty) return;
      // The upstream titles carry emoji, which never appear in the interface.
      final title = cleanStreamText(rawTitle);
      if (title.isEmpty) return;
      if (result.any((row) => row.title == title)) return;
      result.add((title: title, items: items));
    }

    for (final entry in entries) {
      final group = asMap(entry);
      if (group == null) continue;
      final title = asString(
        group['title'] ?? group['name'] ?? group['tabTitle'],
      );

      // The titles of the item itself.
      collect(title, asList(group['subjects']) ?? const []);

      // The ranking rows, for example "Trending movies".
      final ranking = asMap(group['rankingListData']);
      for (final rankingEntry in asList(ranking?['items']) ?? const []) {
        final rankingGroup = asMap(rankingEntry);
        if (rankingGroup == null) continue;
        collect(
          asString(rankingGroup['title']),
          asList(rankingGroup['subjects']) ?? const [],
        );
      }

      // The banner of the item.
      final banner = asMap(group['banner']);
      final bannerSubjects = <Object?>[];
      for (final bannerEntry in asList(banner?['banners']) ?? const []) {
        final subject = asMap(bannerEntry)?['subject'];
        if (subject != null) bannerSubjects.add(subject);
      }
      collect(title, bannerSubjects);

      // The custom data of the item.
      final custom = asMap(group['customData']);
      final customSubjects = <Object?>[];
      for (final customEntry in asList(custom?['items']) ?? const []) {
        final subject = asMap(customEntry)?['subject'];
        if (subject != null) customSubjects.add(subject);
      }
      collect(title, customSubjects);

      // The nested groups of the item.
      for (final nestedEntry in asList(group['groups']) ?? const []) {
        final nested = asMap(nestedEntry);
        if (nested == null) continue;
        collect(
          asString(nested['title']),
          asList(nested['subjects']) ?? const [],
        );
      }
    }
    return result;
  }

  // ------------------------------------------------------------ 4KHDHub

  /// The rows of the 4KHDHub catalogue.
  Future<List<HomeSection>> _loadFourKHdHubSections() async {
    final client = ref.watch(fourKHdHubClientProvider);
    final latest = await client.latest();
    if (latest.isEmpty) return const [];

    final sections = <HomeSection>[
      HomeSection(
        title: 'Latest releases',
        subtitle: 'From 4KHDHub',
        items: latest,
        sourceLabel: ProviderKind.fourkhdhub.label,
      ),
    ];

    final ultraHd = latest
        .where(
          (item) =>
              item.title.toLowerCase().contains('2160') ||
              item.title.toLowerCase().contains('4k') ||
              item.title.toLowerCase().contains('uhd'),
        )
        .toList();
    if (ultraHd.length >= 3) {
      sections.add(
        HomeSection(
          title: '4K Ultra HD',
          subtitle: 'From 4KHDHub',
          items: ultraHd,
          sourceLabel: ProviderKind.fourkhdhub.label,
        ),
      );
    }

    final series = latest.where((item) => item.isSeries).toList();
    if (series.length >= 3) {
      sections.add(
        HomeSection(
          title: 'Series',
          subtitle: 'From 4KHDHub',
          items: series,
          sourceLabel: ProviderKind.fourkhdhub.label,
        ),
      );
    }

    final movies = latest.where((item) => !item.isSeries).toList();
    if (movies.length >= 3) {
      sections.add(
        HomeSection(
          title: 'Movies',
          subtitle: 'From 4KHDHub',
          items: movies,
          sourceLabel: ProviderKind.fourkhdhub.label,
        ),
      );
    }
    return sections;
  }

  // ------------------------------------------------------------ Dramachi

  /// The rows of the Dramachi catalogue.
  ///
  /// The API does not offer a start page, so the newest year is used to
  /// collect the most recent titles.
  Future<List<HomeSection>> _loadDramachiSections() async {
    final client = ref.watch(dramachiClientProvider);
    final year = DateTime.now().year.toString();
    final latest = await client.search(year);
    if (latest.isEmpty) return const [];

    final sections = <HomeSection>[
      HomeSection(
        title: 'Latest releases',
        subtitle: 'From Dramachi',
        items: latest,
        sourceLabel: ProviderKind.dramachi.label,
      ),
    ];

    final series = latest.where((item) => item.isSeries).toList();
    if (series.length >= 3) {
      sections.add(
        HomeSection(
          title: 'Series',
          subtitle: 'From Dramachi',
          items: series,
          sourceLabel: ProviderKind.dramachi.label,
        ),
      );
    }

    final movies = latest.where((item) => !item.isSeries).toList();
    if (movies.length >= 3) {
      sections.add(
        HomeSection(
          title: 'Movies',
          subtitle: 'From Dramachi',
          items: movies,
          sourceLabel: ProviderKind.dramachi.label,
        ),
      );
    }
    return sections;
  }

  // -------------------------------------------------------------- Addons

  /// The explanation that is shown above the rows.
  String? _hintFor(ProviderKind provider, List<HomeSection> sections) {
    if (provider != ProviderKind.addons) return null;
    final hasStreams = _addons.any(
      (addon) => addon.enabled && addon.providesStream,
    );
    if (hasStreams) return null;
    return 'The installed addons only provide catalogues. Add a stream addon '
        'in the settings to play the titles of this list.';
  }

  List<InstalledAddon> get _addons =>
      ref.read(addonsProvider).value ?? const [];

  /// The catalogues of the installed Stremio addons.
  Future<List<HomeSection>> _loadAddonCatalogs() async {
    final addons = _addons;
    final enabled = addons.where((addon) => addon.enabled).toList();
    if (enabled.isEmpty) return const [];

    final provider = ref.read(providerRegistryProvider)[ProviderKind.addons];
    if (provider is! AddonProvider) return const [];

    final targets = AddonProvider.curatedCatalogs(enabled);
    final sections = <HomeSection>[];
    for (final target in targets) {
      try {
        final items = await provider.catalog(
          manifestUrl: target.manifestUrl,
          type: target.type,
          catalogId: target.catalogId,
        );
        if (items.isEmpty) continue;
        sections.add(
          HomeSection(
            title: target.label,
            subtitle: 'From ${_addonName(enabled, target.manifestUrl)}',
            items: items,
            sourceLabel: _addonName(enabled, target.manifestUrl),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return sections;
  }

  String _addonName(List<InstalledAddon> addons, String manifestUrl) {
    for (final addon in addons) {
      if (addon.manifestUrl == manifestUrl) return addon.name;
    }
    return 'Addons';
  }
}

/// The discovery screen state.
///
/// The provider is part of the key, so a provider change loads a fresh
/// catalogue instead of showing the rows of the previous provider.
final homeControllerProvider =
    AsyncNotifierProvider.family<HomeController, HomeState, ProviderKind>(
      HomeController.new,
    );
