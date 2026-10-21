# Credits and acknowledgements

Snigea is built on the work of other people. This file names every project
that Snigea builds on, the reference implementation it was ported from and the
public services and the packages it uses.

---

## The reference implementation

Snigea is a Flutter port of the ideas, the endpoints and the provider logic of
the following project. The providers of Snigea, the request signing, the
parsing rules, the mirror ranking and the recovery of the upstream fixes were
ported from it.

| Project | Author | Link |
| :--- | :--- | :--- |
| **MovieBox-Tui** — a terminal interface to find, download and stream movies, TV shows and live TV | [mesamirh](https://github.com/mesamirh) | <https://github.com/mesamirh/MovieBox-Tui> |

The project is used with the friendly permission of its author. The upstream
fixes of the pull requests
[#208](https://github.com/mesamirh/MovieBox-Tui/pull/208) and
[#216](https://github.com/mesamirh/MovieBox-Tui/pull/216) — the parsing of the
resource detectors, the exact episode listing of `resource/v2`, the failover
over `resource-position/v2` and the refresh of the expiring media signature —
are part of the provider implementation of Snigea.

Without that project there would be no Snigea. Thank you.

---

## The streaming providers

Snigea hosts nothing. It resolves the public endpoints of the following
providers and plays what they publish. The names, the logos and the content
belong to their respective owners, this project is not affiliated with them.

| Provider | What Snigea uses |
| :--- | :--- |
| **MovieBox** | The catalogue, the search, the details, the resource detectors and the signed streams of the public API. |
| **4KHDHub** | The public release pages and the HubCloud, HubDrive and GreenMotors mirrors. |
| **Dramachi** | The nodeobjects API for the catalogue, the details and the episodes. |
| **BDIX** | The CircleFTP and the DhakaFlix local file indexes, reachable inside a BDIX peering network. |
| **Stremio addons** | The addon manifests, the catalogues and the streams. Cinemeta is pre-installed. |

---

## The packages of the application

| Package | Licence | Used for |
| :--- | :--- | :--- |
| [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) | MIT | The state management, by [Remi Rousselet](https://github.com/rrousselGit/riverpod) and the Riverpod contributors. |
| [go_router](https://pub.dev/packages/go_router) | BSD-3-Clause | The navigation, by the [Flutter](https://github.com/flutter/packages) team. |
| [dio](https://pub.dev/packages/dio) | MIT | The HTTP client, by [cfug](https://github.com/cfug/dio). |
| [drift](https://pub.dev/packages/drift) | MIT | The SQLite database and the migrations, by [simolus3](https://github.com/simolus3/drift). |
| [drift_flutter](https://pub.dev/packages/drift_flutter) | MIT | The database connections of the native and the web target. |
| [media_kit](https://pub.dev/packages/media_kit) | MIT | The playback engine, by the [media-kit](https://github.com/media-kit/media-kit) team. |
| [media_kit_video](https://pub.dev/packages/media_kit_video) | MIT | The embedded video surface. |
| [media_kit_libs_video](https://pub.dev/packages/media_kit_libs_video) | MIT | The native libraries of the video output. |
| [cached_network_image](https://pub.dev/packages/cached_network_image) | MIT | The posters, by [Baseflow](https://github.com/Baseflow/flutter_cached_network_image). |
| [html](https://pub.dev/packages/html) | MIT | The parser of the HTML pages, by the [Dart](https://github.com/dart-lang/tools) team. |
| [crypto](https://pub.dev/packages/crypto) | BSD-3-Clause | The MD5 and the HMAC-MD5 of the request signing. |
| [intl](https://pub.dev/packages/intl) | BSD-3-Clause | The formatting of the dates and the numbers. |
| [collection](https://pub.dev/packages/collection) | BSD-3-Clause | The collection helpers. |
| [path](https://pub.dev/packages/path) | BSD-3-Clause | The paths of the file store. |
| [path_provider](https://pub.dev/packages/path_provider) | BSD-3-Clause | The directories of the platform. |
| [cupertino_icons](https://pub.dev/packages/cupertino_icons) | MIT | The Cupertino icons of the Flutter framework. |

## The packages of the development

| Package | Licence | Used for |
| :--- | :--- | :--- |
| [flutter_lints](https://pub.dev/packages/flutter_lints) | BSD-3-Clause | The lint rules of the analyser. |
| [drift_dev](https://pub.dev/packages/drift_dev) | MIT | The generator of the database code. |
| [build_runner](https://pub.dev/packages/build_runner) | BSD-3-Clause | The code generation of the project. |
| [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) | MIT | The launcher icons of every platform. |
| [image](https://pub.dev/packages/image) | MIT | The logo of the application. |

## The framework and the tools

| Project | Licence | Used for |
| :--- | :--- | :--- |
| [Flutter](https://github.com/flutter/flutter) | BSD-3-Clause | The framework of the application. |
| [Dart](https://github.com/dart-lang/sdk) | BSD-3-Clause | The language. |
| [SQLite](https://sqlite.org) | Public domain | The local database. |
| [sqlite3.dart](https://github.com/simolus3/sqlite3.dart) | MIT | The SQLite WebAssembly build of the web target. |
| [mpv](https://github.com/mpv-player/mpv) | LGPL-2.1-or-later | The decoder of the video output, used by `media_kit`. |
| [GitHub Actions](https://github.com/features/actions) | The service is free for the open source | The continuous integration, the releases and the deployment. |
| [shields.io](https://shields.io) | CC0-1.0 | The badges of the README. |

---

## The assets

| Asset | Source | Licence |
| :--- | :--- | :--- |
| The logo of the application | The original artwork of the project owner | Owned by the project. |
| `assets/sqlite3.wasm` | The release of [sqlite3.dart](https://github.com/simolus3/sqlite3.dart) | MIT |
| `assets/drift_worker.js` | The package [drift](https://github.com/simolus3/drift) | MIT |

The pictures in `Screenshots/` were taken by the maintainer on a device with
the application running. The films and the series that are visible in them
belong to their owners and are only shown as a demonstration of the interface.

---

## The contributors

Every person who reported a defect, answered a question, improved the
documentation or sent a pull request is a part of this project. The list of
the contributions is in the history of the repository and in the releases:

<https://github.com/MurShidM01/Snigea/graphs/contributors>

If you contributed and you are missing here, open an issue and you will be
added.
