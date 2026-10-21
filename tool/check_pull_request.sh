#!/usr/bin/env bash
#
# Validates a pull request before it reaches a human reviewer.
#
# The rules are the ones of CONTRIBUTING.md. The script is executed by the
# continuous integration on every pull request and can be run locally:
#
#   PR_TITLE="feat(player): add the speed control" \
#   PR_BRANCH="feat/player-speed" \
#   PR_BODY="$(cat .github/pull_request_template.md)" \
#   bash tool/check_pull_request.sh
#
set -uo pipefail

TITLE="${PR_TITLE:-}"
BRANCH="${PR_BRANCH:-}"
BODY="${PR_BODY:-}"

ERRORS=()

fail () {
  ERRORS+=("$1")
}

# ---------------------------------------------------------------------------
# 1. The branch name
# ---------------------------------------------------------------------------
if [ -z "$BRANCH" ]; then
  fail "The branch name is missing."
elif ! [[ "$BRANCH" =~ ^(feat|fix|docs|ci|chore|refactor|test|perf|build)/[a-z0-9]+([._-][a-z0-9]+)*$ ]]; then
  fail "The branch name '$BRANCH' does not follow the rule <type>/<short-description> with a lower case description, for example feat/player-speed."
fi

# ---------------------------------------------------------------------------
# 2. The title of the pull request
# ---------------------------------------------------------------------------
if [ -z "$TITLE" ]; then
  fail "The title of the pull request is missing."
elif ! [[ "$TITLE" =~ ^(feat|fix|docs|ci|chore|refactor|test|perf|build)(\([a-z0-9._/-]+\))?!?:\ [a-zA-Z].+ ]]; then
  fail "The title '$TITLE' does not follow the rule <type>(<scope>): <description>, for example 'feat(player): add the speed control'."
fi

# ---------------------------------------------------------------------------
# 3. The body of the pull request
# ---------------------------------------------------------------------------
if [ -z "$BODY" ]; then
  fail "The body of the pull request is empty, the template of .github/pull_request_template.md is mandatory."
else
  for section in "## What" "## Why" "## How was it tested" "## Checklist"; do
    if ! grep -Fq "$section" <<< "$BODY"; then
      fail "The body of the pull request is missing the section '$section'."
    fi
  done
  if grep -Fq '<!--' <<< "$BODY"; then
    fail "The body of the pull request still contains the placeholder comments of the template, every section has to be filled in."
  fi
  if ! grep -Eq '^-\s\[[xX]\]' <<< "$BODY"; then
    fail "Not a single item of the checklist is confirmed, the checklist of the template has to be filled in."
  fi
fi

# ---------------------------------------------------------------------------
# 4. The result
# ---------------------------------------------------------------------------
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "::error::The pull request does not follow the contribution rules of CONTRIBUTING.md."
  for error in "${ERRORS[@]}"; do
    echo "::error::$error"
  done
  echo
  echo "Read CONTRIBUTING.md and the template of .github/pull_request_template.md."
  exit 1
fi

echo "The pull request follows the contribution rules."
exit 0
