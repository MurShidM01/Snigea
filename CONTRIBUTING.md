# Contributing to Snigea

Thank you for taking the time to improve Snigea. This document is **binding**.
Every rule marked with **[STRICT]** is checked by the pipeline or by the
maintainer during the review, and a pull request that breaks one of them is
closed without a review. There is no exception for "small" changes, for a
first contribution or for a change that is "only" a rename.

Snigea is a pure Dart Flutter application. The project is small on purpose and
stays that way: a change that makes the code base harder to read is a change
that will not be merged, even when it is correct.

---

## Table of contents

1. [The hard rules](#1-the-hard-rules)
2. [Before you start](#2-before-you-start)
3. [The branch](#3-the-branch)
4. [The commits](#4-the-commits)
5. [The pull request](#5-the-pull-request)
6. [The checklist that the pipeline enforces](#6-the-checklist-that-the-pipeline-enforces)
7. [The code style](#7-the-code-style)
8. [The rules of the interface](#8-the-rules-of-the-interface)
9. [The rules for the providers](#9-the-rules-for-the-providers)
10. [The database and the migrations](#10-the-database-and-the-migrations)
11. [The tests](#11-the-tests)
12. [The dependencies](#12-the-dependencies)
13. [The secrets and the signing](#13-the-secrets-and-the-signing)
14. [The files that must never be committed](#14-the-files-that-must-never-be-committed)
15. [The screenshots](#15-the-screenshots)
16. [The releases](#16-the-releases)
17. [The review](#17-the-review)
18. [The reports of defects](#18-the-reports-of-defects)
19. [The security problems](#19-the-security-problems)
20. [The licence](#20-the-licence)
21. [The code of conduct](#21-the-code-of-conduct)

---

## 1. The hard rules

| # | Rule | Consequence |
| :-- | :--- | :--- |
| 1 | **`main` is never committed on directly.** Every change arrives as a pull request from a branch. | The push is rejected, the branch protection blocks it. |
| 2 | **One pull request carries one logical change.** A refactoring, a new function and a fix of an unrelated defect belong to three pull requests. | The pull request is split by the maintainer before the review. |
| 3 | **The pull request fills in the whole template.** The four sections and the checklist are mandatory. | The pipeline rejects the pull request. |
| 4 | **The branch name is `<type>/<short-description>`** in lower case, for example `feat/player-speed`. | The pipeline rejects the pull request. |
| 5 | **The title is `<type>(<scope>): <description>`**, for example `feat(player): add the speed control`. | The pipeline rejects the pull request. |
| 6 | **The commits follow the conventional commits** and every commit is a single logical step. | The maintainer asks for a rebase before the review. |
| 7 | **The pipeline is green.** Format, analyse, tests, web build and the release Android build have to pass. | The pull request is not reviewed. |
| 8 | **`flutter analyze` reports no issue** and **`dart format` changes nothing.** | The pipeline rejects the pull request. |
| 9 | **Every new behaviour has a test, every fixed defect has a regression test.** | The maintainer asks for the missing test. |
| 10 | **No secret, key, token, session cookie or signed url is ever committed or printed.** | The pull request is closed, the history is rewritten. |
| 11 | **No native code.** No Kotlin, no Swift, no C, no FFI, no platform channel of your own. | The pull request is closed. |
| 12 | **The platform folders keep the structure of the Flutter template.** No rewrite of the project files, no change of the application id, no change of the bundle id. | The maintainer asks for a rework. |
| 13 | **The version in `pubspec.yaml` is not touched.** The maintainer raises it with the release. | The change is removed from the pull request. |
| 14 | **No build output, no dependency folder and no editor file is committed.** | The pipeline rejects the pull request. |
| 15 | **No release is published by a contributor.** Only the maintainer creates a tag. | The tag is deleted. |
| 16 | **No upstream provider is hammered.** The live checks run in a controlled way, they are never part of the test suite. | The pull request is closed. |
| 17 | **The interface stays flat, without shadow, without elevation and without emoji in a label.** | The maintainer asks for a rework. |
| 18 | **No copyright protected content is added to the repository.** | The pull request is closed. |

---

## 2. Before you start

- **Open an issue first** for everything that changes the behaviour, the
  providers, the database or the dependencies. A pull request without an issue
  is closed, the exception is a fix of a defect that nobody reported yet.
- **Search the open pull requests.** A change that is already in flight is
  merged from that branch instead of a second one.
- **Keep the scope small.** A pull request that touches more than about 400
  lines, or more than five files of the same area, is split. The pipeline does
  not measure it, the reviewer does.
- **Ask before you start** if the change touches the signing, the workflows, the
  database schema, the player or the providers. Those areas have a reason for
  their current shape.

---

## 3. The branch

**[STRICT]** The branch name is `<type>/<short-description>`:

| Type | For |
| :--- | :--- |
| `feat` | A new function |
| `fix` | A repair of a defect |
| `refactor` | A change of the internal structure without a new function |
| `perf` | A change of the speed or of the memory |
| `test` | Tests only |
| `docs` | The README, the doc comments, the comments |
| `ci` | The workflows, the scripts of `tool/` |
| `build` | The platform folders, the dependencies, the generated assets |
| `chore` | Everything that does not change the product |

The description is lower case, uses dashes and describes the change:

```
feat/player-speed
fix/moviebox-signature-refresh
docs/provider-table
ci/pr-lint
```

- The branch is created from the current `main`, never from an outdated branch.
- The branch is pushed to your fork, never to a branch of somebody else.
- The branch is not reused for a second pull request. A new topic, a new
  branch.

---

## 4. The commits

**[STRICT]** The commits follow the [conventional commits](https://www.conventionalcommits.org):

```
<type>(<scope>): <subject>

<body>

<footer>
```

- The subject is written in the imperative, in lower case, without a period at
  the end: `fix(player): keep the aspect ratio of the surface`.
- The body explains **why** the change was needed and not **what** the diff
  already shows. Every line is at most 72 characters.
- The footer carries the issue: `Closes #42`.
- The types are the ones of the branch table above.
- Every commit is a single logical step that leaves the code base compiling
  and the tests green. A commit that breaks the build is not allowed in the
  history, not even in the middle.
- The merge of the branch is done with **squash** by the maintainer, so the
  commit titles of the branch have to be readable on their own.

Examples of a good history:

```
feat(player): add the audio and speed sheet
fix(moviebox): refresh the signed url before the playback
docs(readme): document the fixed signing key
```

---

## 5. The pull request

**[STRICT]** The pull request is opened against `main` and uses the template of
[`.github/pull_request_template.md`](.github/pull_request_template.md) without
changing its section titles.

1. **Title** — `<type>(<scope>): <description>`, for example
   `feat(downloads): show the remaining time of a download`.
2. **What** — the change in one or two sentences, with the names of the screens,
   the providers and the services.
3. **Why** — the reason and the issue it closes (`Closes #42`).
4. **How was it tested** — the commands, the screens and the device. The
   pipeline runs the checks on every platform, the manual part is yours.
5. **Type of change** — exactly one tick, or several when the change really
   touches several areas.
6. **Checklist** — every point has to be answered with `[x]`. A point that does
   not apply is removed from the checklist, it is not left unticked.
7. **Notes for the reviewer** — the risky parts and the open questions.

Further rules:

- **[STRICT]** The pull request is opened from a branch of your fork, the head
  branch is deleted after the merge.
- **[STRICT]** The branch is never force pushed after a review has started. The
  maintainer asks for the changes, you push them, the history is not rewritten.
- **[STRICT]** The diff contains no unrelated change. A file that is formatted
  differently because of an editor setting is reverted, the formatter of the
  project decides.
- **[STRICT]** Screenshots of a changed screen are added to `Screenshots/`, see
  the section below.
- The pull request is reviewed by the maintainer. A pull request that is not
  updated for 14 days is closed and can be reopened later.

---

## 6. The checklist that the pipeline enforces

The workflow [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on
every pull request and on every push to `main`:

| Check | Command | Fails when |
| :--- | :--- | :--- |
| Pull request rules | `tool/check_pull_request.sh` | The branch name, the title, a section of the template or the checklist does not match the rules of this document. |
| Format | `dart format --output=none --set-exit-if-changed lib test tool` | A file is not formatted the way the formatter wants. |
| Analyse | `flutter analyze --no-fatal-infos` | The analyser reports an issue. |
| Tests | `flutter test` | A test fails. |
| Web build | `flutter build web --release` | The web target does not compile. |
| Android build | `flutter build apk --release` | The release build of the Android target fails. |

The pull request rules can be run locally before you push:

```bash
PR_TITLE="feat(player): add the speed control" \
PR_BRANCH="feat/player-speed" \
PR_BODY="$(cat .github/pull_request_template.md)" \
bash tool/check_pull_request.sh
```

**[STRICT]** A pull request with a red pipeline is never reviewed. Fix the
pipeline, do not ask for a review anyway.

---

## 7. The code style

- **[STRICT]** The formatter decides, never the editor:
  `dart format lib test tool`.
- **[STRICT]** The analyser decides:
  `flutter analyze`. A suppression with `// ignore:` needs a comment that
  explains why the rule does not apply.
- **[STRICT]** The imports are relative, exactly like the rest of the project:
  `import '../../core/theme/app_theme.dart';`. The package name is `snigea`,
  the import `package:snigea/...` is only used in the tests and in the scripts
  of `tool/`.
- **[STRICT]** Every public class, every public function and every non obvious
  field carries a doc comment that starts with a sentence and ends with a
  period. The comments explain **why**, the diff already shows the **what**.
- **[STRICT]** No `print`, no `debugPrint`, no `TODO` without a linked issue,
  no commented out code, no dead code. The logger of
  `lib/core/logging/app_logger.dart` is used instead, it never prints a
  credential or a query string.
- **[STRICT]** No magic numbers. A constant with a name is used, the spacing
  tokens of `lib/core/theme/app_spacing.dart` and the palette of
  `lib/core/theme/app_palette.dart` are reused.
- The lines are at most 80 characters.
- A file does not exceed about 700 lines. A file that grows too much is split
  along its concerns.
- The naming follows the Dart conventions: `lowerCamelCase` for the values and
  the methods, `UpperCamelCase` for the types, `SCREAMING_SNAKE_CASE` for the
  constants.
- Prefer `final` over `var`, `late` only where it is unavoidable.
- Prefer an immutable model over a mutable one, the domain models are
  immutable.

---

## 8. The rules of the interface

Snigea uses a flat design language. These rules are not a suggestion, they are
checked in `test/core/theme_test.dart` and in the widget tests.

- **[STRICT]** No shadow and no elevation. The separation is done with a
  hairline border and with the tonal steps of the palette.
- **[STRICT]** No emoji in any label, title or chip. The upstream texts are
  cleaned with `cleanStreamText` before they reach the interface.
- **[STRICT]** No pill and no rounded rectangle behind the active icon of the
  navigation bar, the accent colour marks the active destination.
- **[STRICT]** The spacing follows the 4 pixel grid of `AppSpacing`, the radius
  the tokens of the theme. No ad hoc numbers.
- **[STRICT]** Every screen has to work in the light theme, in the dark theme
  and in the system mode. A widget that only works in one theme is a defect.
- **[STRICT]** Every screen has to work with the text scale of the system and
  without an overflow at the smallest supported size.
- The icons come from Material, the interface never draws an icon with a
  character or with an image of an upstream page.
- A new widget goes into `lib/widgets/`, a screen into `lib/features/<area>/`.

---

## 9. The rules for the providers

The providers are the part of the application that breaks the most often, so
the rules here are the strictest.

- **[STRICT]** A provider is implemented in pure Dart under
  `lib/providers/<provider>/`, without a dependency on the interface.
- **[STRICT]** The parsing lives in a separate `*_parser.dart` that works on
  plain maps and lists. The parsers are pure functions without a network
  access, that is what makes them testable.
- **[STRICT]** Every parser has a test with a payload of the upstream
  response. A parser without a test is not merged.
- **[STRICT]** The request signing, the header set and the user agent of a
  provider stay inside its client. The other providers never see them.
- **[STRICT]** The signed links, the session tokens and the cookies are never
  written into a log, an error message or an issue.
- **[STRICT]** The live checks in `tool/` are never part of `flutter test`. They
  run against the real upstream and they are only started manually, with a
  deliberate delay between the requests.
- **[STRICT]** A change of an upstream endpoint comes with the payload that
  proves the new shape and with a note in the pull request about the date of
  the observation.
- The upstream answers with an empty result or with an error. The interface
  explains the situation instead of showing an empty screen.

---

## 10. The database and the migrations

- **[STRICT]** The schema lives in `lib/data/database/tables.dart` and the
  migrations in `lib/data/database/app_database.dart`.
- **[STRICT]** A change of the schema raises the version of the schema and adds
  a migration. A column is never removed, it is only added, so that an existing
  installation keeps its data.
- **[STRICT]** The generated code (`app_database.g.dart`) is regenerated with
  `dart run build_runner build` and committed with the change.
- **[STRICT]** A migration has a test in `test/data/database_test.dart` that
  opens an old schema, runs the migration and checks the data.
- The database is local, there is no server and no sync. A change that needs
  one is out of scope for the project.

---

## 11. The tests

- **[STRICT]** Every new behaviour has a test. Every fixed defect has a
  regression test that fails without the fix.
- **[STRICT]** The test suite never touches the network. A test that needs the
  network belongs into `tool/`.
- **[STRICT]** A test is deterministic: no sleep of a second, no real clock, no
  random value without a seed, no dependency on the order of the tests.
- **[STRICT]** The tests live in `test/` and mirror the structure of `lib/`:
  a test of `lib/providers/moviebox/moviebox_parser.dart` is
  `test/providers/moviebox_test.dart`.
- A widget test that touches the player has to return early when the host does
  not provide `libmpv`, exactly like `test/widgets/player_page_test.dart`.
- The visual test renders every screen with the real font and writes the
  pictures into `build/screenshots/`. It never compares the pixels, a
  different renderer on the runner must not turn the pipeline red.
- The screenshots of the README are **not** generated by the test suite, they
  are real pictures of a device.

---

## 12. The dependencies

- **[STRICT]** A new dependency is discussed in an issue before it is added. A
  pull request that adds a package without a discussion is closed.
- **[STRICT]** `pubspec.yaml` and `pubspec.lock` are always changed together.
- **[STRICT]** The version constraint is a caret range, never an exact version.
- The dependencies of the project are minimal on purpose: Riverpod, go_router,
  Dio, Drift, media_kit and a small set of parsers. A package that replaces a
  part of them has to argue why.
- A package that is only needed by a script of `tool/` belongs into the
  development dependencies.
- **[STRICT]** No package that is not published on pub.dev and no package from a
  git repository, the build of the pipeline has to stay reproducible.

---

## 13. The secrets and the signing

- **[STRICT]** No keystore, no password, no token, no cookie and no signed url
  is ever committed. `android/key.properties`, `*.jks` and `*.keystore` are
  ignored by Git and stay outside the repository.
- **[STRICT]** The signing identity of the releases is the one of the
  repository secrets. A contributor never creates, rotates or replaces it.
- **[STRICT]** The application id `com.aliedu.app.snigea` and the bundle id
  stay the same. A change of the id breaks the update path of every installed
  application and is a decision of the maintainer alone.
- **[STRICT]** A log never contains a credential, a session token, a signed url
  or the full query string of a request.
- The secrets of the repository are read only by the release workflow, which
  runs on a tag. A pull request never reaches them.

---

## 14. The files that must never be committed

**[STRICT]** The following paths are ignored by Git and must not appear in a
pull request:

```
build/                    the output of every build
.dart_tool/               the resolved packages
.flutter-plugins-dependencies
android/key.properties    the local signing configuration
*.jks  *.keystore         the keystores
.idea/  *.iml             the files of the editor
```

The following paths are tracked and are part of the repository:

```
lib/                      the application
test/                     the test suite
tool/                     the scripts, the live checks and the icon generator
assets/                   the drift assets and the icon
Screenshots/              the pictures of the real device
.github/workflows/        the pipelines
```

If a build output or an editor file shows up in the diff, the pull request is
sent back before the review starts.

---

## 15. The screenshots

- **[STRICT]** The pictures in `Screenshots/` are real screenshots of the
  application on a device. A rendering of the test suite is not a screenshot
  for the README.
- **[STRICT]** The name is the name of the screen in lower case with a dash:
  `player-inline.jpg`, `player-fullscreen.jpg`, `home.jpg`, `details.jpg`,
  `search.jpg`, `library.jpg`, `downloads.jpg`, `settings.jpg`.
- **[STRICT]** A change of the interface that is visible on a screen comes with
  the new picture of that screen.
- **[STRICT]** A picture shows no personal data: no account, no notification, no
  name and no file of the person who took it.
- The pictures are in the JPEG format, at most 400 kB each.
- The logo of the application is generated from `assets/icon/Snigea.png` with
  `dart run flutter_launcher_icons` and `dart run tool/generate_logo_asset.dart`.
  It is never replaced by another file without a discussion.

---

## 16. The releases

- **[STRICT]** Only the maintainer creates a tag and publishes a release. A
  contributor never pushes a tag, never touches the workflow of the release and
  never changes the version in `pubspec.yaml`.
- The version in `pubspec.yaml` is the single source of truth. The tag is
  `v<version>`, for example `v1.0.1` for the version `1.0.1+12`.
- The build number after the `+` increases with every release, otherwise the
  update of an installed application is refused.
- The release workflow validates the tag against `pubspec.yaml`, builds the
  signed APK and the App Bundle, verifies the signature and publishes the
  release with the checksums. A tag that does not match is rejected.

---

## 17. The review

- The maintainer reviews the pull requests in the order of their arrival. A
  review usually takes a few days.
- The review asks for changes when a rule of this document is broken, when the
  behaviour is not covered by a test or when the code is hard to read. The
  comments name the file and the line.
- A pull request that needs many rounds of review is often too large. Ask
  earlier, split earlier.
- The maintainer may ask for a change of the implementation even when the
  behaviour is correct. The goal is the code base, not the pull request.
- When the review is positive, the maintainer squashes the branch into `main`
  and deletes the branch of the fork.
- The decision is final for the code. A new pull request with a different
  approach is always welcome.

---

## 18. The reports of defects

A defect report has to answer:

1. The version of the application (the build screen) and the platform.
2. The provider and the exact screen.
3. What was expected and what happened.
4. The steps to reproduce it.
5. The log of the application, **without** a token, a cookie or a signed url.

The log is written by the logger of the application into the files of the
platform. A report without the steps to reproduce it is closed.

---

## 19. The security problems

**[STRICT]** A security problem is **not** reported in a public issue.

Report it privately to the maintainer, with a description of the problem, the
affected version and the steps to reproduce it. The maintainer has two days to
prepare a fix, and the report stays private until a release with the fix is
published.

A vulnerability that is published before a fix exists is not a report that can
be handled, and it puts the users of the application at risk.

---

## 20. The licence

Snigea is **dual licensed** under the Apache License 2.0 and the MIT licence,
at your option. The full texts are in [LICENSE](../LICENSE) and in
[LICENSE-MIT](../LICENSE-MIT), the notice with the attributions is in
[NOTICE](../NOTICE).

- **[STRICT]** Every contribution is published under the same dual licence.
  A contribution that arrives with another licence is not merged.
- **[STRICT]** The contributor confirms that they are allowed to publish the
  code and that they have the right on every part of it.
- **[STRICT]** The credit of the reference implementation and of every third
  party component is kept. A new package, a new asset or a new provider comes
  with its entry in [CREDITS.md](../CREDITS.md).
- **[STRICT]** No content that is protected by a copyright is added: no
  movies, no episodes, no subtitles, no posters, no artwork of a provider.
  The application plays what the providers publish, it stores nothing.
- The names and the logos of the providers belong to their owners. This project
  is not affiliated with them.

The reference implementation of the providers is
[MovieBox-Tui](https://github.com/mesamirh/MovieBox-Tui) by
[mesamirh](https://github.com/mesamirh). A change of the providers keeps the
credit of that project in place, it never replaces it.

---

## 21. The code of conduct

- Be respectful. A review is about the code, never about the person.
- Argue with arguments, with a test or with a measurement.
- Do not repeat the same comment three times, mark the threads that are
  resolved.
- Harassment, personal attacks and the exclusion of other contributors are not
  accepted and lead to the removal of the access.
- A maintainer that breaks these rules is subject to the same rules.

---

**Thank you.** A project like Snigea survives because people spend an evening
on a small fix and explain why it matters. The rules above exist so that the
next person can find their way through the code base in an afternoon.
