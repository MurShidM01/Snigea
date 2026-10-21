import '../../core/json/json_utils.dart';

/// A resource exposed by a Stremio addon.
class AddonResource {
  const AddonResource({
    required this.name,
    this.types = const [],
    this.idPrefixes = const [],
  });

  final String name;
  final List<String> types;
  final List<String> idPrefixes;

  /// Parses the `resources` entry of a manifest.
  static List<AddonResource> parseList(Object? raw) {
    final resources = <AddonResource>[];
    for (final entry in asList(raw) ?? const []) {
      if (entry is String) {
        resources.add(AddonResource(name: entry));
        continue;
      }
      final map = asMap(entry);
      if (map == null) continue;
      final name = asString(map['name']);
      if (name == null) continue;
      resources.add(
        AddonResource(
          name: name,
          types: (asList(map['types']) ?? const [])
              .map(asString)
              .whereType<String>()
              .toList(),
          idPrefixes: (asList(map['idPrefixes']) ?? const [])
              .map(asString)
              .whereType<String>()
              .toList(),
        ),
      );
    }
    return resources;
  }
}

/// An extra parameter of a catalogue.
class CatalogExtra {
  const CatalogExtra({
    required this.name,
    this.isRequired = false,
    this.options = const [],
  });

  final String name;
  final bool isRequired;
  final List<String> options;
}

/// A catalogue exposed by a Stremio addon.
class CatalogDefinition {
  const CatalogDefinition({
    required this.type,
    required this.id,
    this.name,
    this.extra = const [],
  });

  final String type;
  final String id;
  final String? name;
  final List<CatalogExtra> extra;

  static List<CatalogDefinition> parseList(Object? raw) {
    final catalogs = <CatalogDefinition>[];
    for (final entry in asList(raw) ?? const []) {
      final map = asMap(entry);
      if (map == null) continue;
      final type = asString(map['type']);
      final id = asString(map['id']);
      if (type == null || id == null) continue;
      final extras = <CatalogExtra>[];
      for (final extraEntry in asList(map['extra']) ?? const []) {
        final extraMap = asMap(extraEntry);
        if (extraMap == null) continue;
        final name = asString(extraMap['name']);
        if (name == null) continue;
        extras.add(
          CatalogExtra(
            name: name,
            isRequired:
                asString(extraMap['isRequired']) == 'true' ||
                extraMap['isRequired'] == true,
            options: (asList(extraMap['options']) ?? const [])
                .map(asString)
                .whereType<String>()
                .toList(),
          ),
        );
      }
      catalogs.add(
        CatalogDefinition(
          type: type,
          id: id,
          name: asString(map['name']),
          extra: extras,
        ),
      );
    }
    return catalogs;
  }
}

/// The manifest of a Stremio addon.
class AddonManifest {
  const AddonManifest({
    required this.id,
    required this.name,
    this.version,
    this.description,
    this.resources = const [],
    this.types = const [],
    this.catalogs = const [],
    this.idPrefixes = const [],
    this.logo,
    this.background,
  });

  final String id;
  final String name;
  final String? version;
  final String? description;
  final List<AddonResource> resources;
  final List<String> types;
  final List<CatalogDefinition> catalogs;
  final List<String> idPrefixes;
  final String? logo;
  final String? background;

  bool providesResource(String name) => resources.any(
    (resource) => resource.name.toLowerCase() == name.toLowerCase(),
  );

  bool get providesStream => providesResource('stream');

  bool get providesMeta => providesResource('meta');

  bool get providesCatalog =>
      providesResource('catalog') || catalogs.isNotEmpty;

  static AddonManifest fromJson(Map<String, Object?> json) {
    final id = asString(json['id']) ?? '';
    final name = asString(json['name']) ?? '';
    return AddonManifest(
      id: id,
      name: name,
      version: asString(json['version']),
      description: asString(json['description']),
      resources: AddonResource.parseList(json['resources']),
      types: (asList(json['types']) ?? const [])
          .map(asString)
          .whereType<String>()
          .toList(),
      catalogs: CatalogDefinition.parseList(json['catalogs']),
      idPrefixes: (asList(json['idPrefixes']) ?? const [])
          .map(asString)
          .whereType<String>()
          .toList(),
      logo: asString(json['logo']),
      background: asString(json['background']),
    );
  }
}

/// An addon the user installed.
class InstalledAddon {
  const InstalledAddon({
    required this.manifestUrl,
    required this.name,
    this.version,
    this.description,
    this.enabled = true,
    this.providesCatalog = false,
    this.providesMeta = false,
    this.providesStream = false,
    this.idPrefixes = const [],
    this.types = const [],
  });

  final String manifestUrl;
  final String name;
  final String? version;
  final String? description;
  final bool enabled;
  final bool providesCatalog;
  final bool providesMeta;
  final bool providesStream;
  final List<String> idPrefixes;
  final List<String> types;

  /// The manifest of the official Cinemeta catalogue addon.
  static const String cinemetaManifest =
      'https://v3-cinemeta.strem.io/manifest.json';

  /// The default addon that is always present.
  factory InstalledAddon.cinemetaDefault() => const InstalledAddon(
    manifestUrl: cinemetaManifest,
    name: 'Cinemeta',
    version: '3.0.14',
    description: 'Official catalog and metadata',
    providesCatalog: true,
    providesMeta: true,
    idPrefixes: ['tt'],
    types: ['movie', 'series'],
  );

  /// True for the bundled Cinemeta addon.
  bool get isCore =>
      name.toLowerCase() == 'cinemeta' ||
      manifestUrl.toLowerCase().contains('cinemeta');

  /// Builds an installed addon from its manifest.
  factory InstalledAddon.fromManifest(
    String manifestUrl,
    AddonManifest manifest,
  ) => InstalledAddon(
    manifestUrl: manifestUrl,
    name: manifest.name,
    version: manifest.version,
    description: manifest.description,
    enabled: true,
    providesCatalog: manifest.providesCatalog,
    providesMeta: manifest.providesMeta,
    providesStream: manifest.providesStream,
    idPrefixes: manifest.idPrefixes,
    types: manifest.types,
  );

  /// Serialisable representation.
  Map<String, Object?> toJson() => {
    'manifest_url': manifestUrl,
    'name': name,
    'version': version,
    'description': description,
    'enabled': enabled,
    'provides_catalog': providesCatalog,
    'provides_meta': providesMeta,
    'provides_stream': providesStream,
    'id_prefixes': idPrefixes,
    'types': types,
  };

  /// Restores an addon from its serialised form.
  static InstalledAddon fromJson(Map<String, Object?> json) => InstalledAddon(
    manifestUrl: asString(json['manifest_url']) ?? '',
    name: asString(json['name']) ?? 'Unknown',
    version: asString(json['version']),
    description: asString(json['description']),
    enabled: json['enabled'] != false,
    providesCatalog: json['provides_catalog'] == true,
    providesMeta: json['provides_meta'] == true,
    providesStream: json['provides_stream'] == true,
    idPrefixes: (asList(json['id_prefixes']) ?? const [])
        .map(asString)
        .whereType<String>()
        .toList(),
    types: (asList(json['types']) ?? const [])
        .map(asString)
        .whereType<String>()
        .toList(),
  );

  InstalledAddon copyWith({bool? enabled}) => InstalledAddon(
    manifestUrl: manifestUrl,
    name: name,
    version: version,
    description: description,
    enabled: enabled ?? this.enabled,
    providesCatalog: providesCatalog,
    providesMeta: providesMeta,
    providesStream: providesStream,
    idPrefixes: idPrefixes,
    types: types,
  );
}

/// A catalogue entry returned by an addon.
class MetaItem {
  const MetaItem({
    required this.id,
    required this.type,
    required this.name,
    this.title,
    this.poster,
    this.cover,
    this.description,
    this.overview,
    this.synopsis,
    this.releaseInfo,
    this.year,
    this.released,
    this.imdbRating,
    this.rating,
    this.genres = const [],
    this.genre = const [],
  });

  final String id;
  final String type;
  final String name;
  final String? title;
  final String? poster;
  final String? cover;
  final String? description;
  final String? overview;
  final String? synopsis;
  final String? releaseInfo;
  final String? year;
  final String? released;
  final String? imdbRating;
  final String? rating;
  final List<String> genres;
  final List<String> genre;

  static MetaItem fromJson(Map<String, Object?> json) => MetaItem(
    id: asString(json['id']) ?? '',
    type: asString(json['type']) ?? '',
    name: asString(json['name']) ?? '',
    title: asString(json['title']),
    poster: asString(json['poster']),
    cover: asString(json['cover']),
    description: asString(json['description']),
    overview: asString(json['overview']),
    synopsis: asString(json['synopsis']),
    releaseInfo: asString(json['releaseInfo']),
    year: asString(json['year']),
    released: asString(json['released']),
    imdbRating: asString(json['imdbRating']),
    rating: asString(json['rating']),
    genres: _stringList(json['genres']),
    genre: _stringList(json['genre']),
  );
}

/// One episode of a series, as described by an addon.
class MetaVideo {
  const MetaVideo({
    this.id,
    this.title,
    this.name,
    this.season,
    this.episode,
    this.number,
    this.released,
    this.thumbnail,
    this.overview,
    this.description,
  });

  final String? id;
  final String? title;
  final String? name;
  final int? season;
  final int? episode;
  final int? number;
  final String? released;
  final String? thumbnail;
  final String? overview;
  final String? description;

  static MetaVideo fromJson(Map<String, Object?> json) => MetaVideo(
    id: asString(json['id']),
    title: asString(json['title']),
    name: asString(json['name']),
    season: asInt(json['season']),
    episode: asInt(json['episode']) ?? asInt(json['number']),
    number: asInt(json['number']),
    released: asString(json['released']),
    thumbnail: asString(json['thumbnail']),
    overview: asString(json['overview']),
    description: asString(json['description']),
  );
}

/// The full metadata of a title.
class MetaDetail {
  const MetaDetail({
    required this.id,
    required this.type,
    required this.name,
    this.title,
    this.poster,
    this.cover,
    this.background,
    this.logo,
    this.description,
    this.overview,
    this.synopsis,
    this.releaseInfo,
    this.year,
    this.released,
    this.imdbRating,
    this.rating,
    this.genres = const [],
    this.genre = const [],
    this.runtime,
    this.cast = const [],
    this.stars = const [],
    this.director = const [],
    this.directors = const [],
    this.writer = const [],
    this.writers = const [],
    this.videos = const [],
  });

  final String id;
  final String type;
  final String name;
  final String? title;
  final String? poster;
  final String? cover;
  final String? background;
  final String? logo;
  final String? description;
  final String? overview;
  final String? synopsis;
  final String? releaseInfo;
  final String? year;
  final String? released;
  final String? imdbRating;
  final String? rating;
  final List<String> genres;
  final List<String> genre;
  final String? runtime;
  final List<String> cast;
  final List<String> stars;
  final List<String> director;
  final List<String> directors;
  final List<String> writer;
  final List<String> writers;
  final List<MetaVideo> videos;

  static MetaDetail fromJson(Map<String, Object?> json) => MetaDetail(
    id: asString(json['id']) ?? '',
    type: asString(json['type']) ?? '',
    name: asString(json['name']) ?? '',
    title: asString(json['title']),
    poster: asString(json['poster']),
    cover: asString(json['cover']),
    background: asString(json['background']),
    logo: asString(json['logo']),
    description: asString(json['description']),
    overview: asString(json['overview']),
    synopsis: asString(json['synopsis']),
    releaseInfo: asString(json['releaseInfo']),
    year: asString(json['year']),
    released: asString(json['released']),
    imdbRating: asString(json['imdbRating']),
    rating: asString(json['rating']),
    genres: _stringList(json['genres']),
    genre: _stringList(json['genre']),
    runtime: asString(json['runtime']),
    cast: _stringList(json['cast']),
    stars: _stringList(json['stars']),
    director: _stringList(json['director']),
    directors: _stringList(json['directors']),
    writer: _stringList(json['writer']),
    writers: _stringList(json['writers']),
    videos: (asList(json['videos']) ?? const [])
        .map(asMap)
        .whereType<Map<String, Object?>>()
        .map(MetaVideo.fromJson)
        .toList(),
  );
}

/// A single stream offered by an addon.
class StreamItem {
  const StreamItem({
    this.name,
    this.title,
    this.description,
    this.url,
    this.behaviorHints,
  });

  final String? name;
  final String? title;
  final String? description;
  final String? url;
  final StreamBehaviorHints? behaviorHints;

  static StreamItem fromJson(Map<String, Object?> json) {
    final hints = asMap(json['behaviorHints']);
    return StreamItem(
      name: asString(json['name']),
      title: asString(json['title']),
      description: asString(json['description']),
      url: asString(json['url']),
      behaviorHints: hints == null ? null : StreamBehaviorHints.fromJson(hints),
    );
  }
}

/// Hints that describe how a stream should be played.
class StreamBehaviorHints {
  const StreamBehaviorHints({
    this.notWebReady = false,
    this.headers = const {},
    this.videoSize,
    this.filename,
  });

  final bool notWebReady;
  final Map<String, String> headers;
  final int? videoSize;
  final String? filename;

  static StreamBehaviorHints fromJson(Map<String, Object?> json) {
    final headers = <String, String>{};
    final rawHeaders = asMap(json['headers']);
    if (rawHeaders != null) {
      rawHeaders.forEach((key, value) {
        final text = asString(value);
        if (text != null) headers[key] = text;
      });
    }
    return StreamBehaviorHints(
      notWebReady: json['notWebReady'] == true,
      headers: headers,
      videoSize: asInt(json['videoSize']),
      filename: asString(json['filename']),
    );
  }
}

List<String> _stringList(Object? raw) {
  if (raw == null) return const [];
  if (raw is String) {
    return raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }
  final list = asList(raw);
  if (list == null) return const [];
  final result = <String>[];
  for (final entry in list) {
    final text = asString(entry);
    if (text != null && text.trim().isNotEmpty) {
      result.add(text.trim());
    } else {
      final name = asString(asMap(entry)?['name']);
      if (name != null && name.trim().isNotEmpty) result.add(name.trim());
    }
  }
  return result;
}
