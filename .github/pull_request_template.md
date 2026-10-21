<!--
Every pull request has to fill in this template. The pipeline rejects a pull
request with a missing section, an empty checklist or a placeholder comment.
Keep the section titles exactly as they are, only the text below them changes.
-->

## What

<!-- What does this pull request change? Name the screens, the providers, the
services or the files that are touched. A single sentence is enough. -->

## Why

<!-- Why is this change needed? Link the issue it closes, for example
"Closes #42". Without a reason the change cannot be reviewed. -->

## How was it tested

<!-- How did you verify the change? Name the commands, the screens you opened
and the device you used. The pipeline runs the format check, the analyser, the
test suite, a web build and a release Android build on every pull request. -->

## Type of change

- [ ] Bug fix (a non breaking change that repairs a defect)
- [ ] New feature (a non breaking change that adds a function)
- [ ] Refactor (a change of the internal structure without a new function)
- [ ] Documentation (the README, the comments or the doc comments)
- [ ] Build, pipeline or dependency (the workflows, the platform folders, the packages)
- [ ] Provider or upstream change (MovieBox, 4KHDHub, Dramachi, BDIX, the addons)

## Checklist

- [ ] `flutter analyze` reports no issue.
- [ ] `dart format --output=none --set-exit-if-changed lib test tool` does not change a file.
- [ ] `flutter test` passes, a new behaviour is covered by a test and a fixed defect has a regression test.
- [ ] The change is limited to the subject of the pull request, no unrelated reformatting and no drive by changes.
- [ ] No secret, key, token, signed url or personal data is part of the diff.
- [ ] No debug output, no commented out code and no unfinished placeholder is left behind.
- [ ] The interface keeps the flat design, it has no shadow, no elevation and no emoji in a label.
- [ ] The change does not break the web target, the database migration is added when the schema changes.
- [ ] The documentation is updated when a behaviour, a provider or a setting changes.
- [ ] The version in `pubspec.yaml` is untouched, the maintainer raises it with the release.

<!--
Anything that does not fit into the checklist is explained in the last
paragraph. A pull request that cannot be merged because of a missing answer
is closed without a review.
-->

## Notes for the reviewer

<!--
The places that need a careful look, the risk of the change and the parts you
are not sure about. Mention it here instead of hiding it in the diff.
-->
