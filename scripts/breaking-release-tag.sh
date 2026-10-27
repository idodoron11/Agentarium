#!/usr/bin/env bash
# Prints the next major version (X.0.0) when a commit since the latest vX.Y.Z tag, or an extra message
# passed as an argument (e.g. a PR title), carries a Conventional Commits "!" breaking marker; prints nothing otherwise.
# The tag action's commit analyzer ignores "!", so its output is passed as `custom_tag`. See docs/adr/0003.
# Usage: scripts/breaking-release-tag.sh [extra-message...]   (run inside a clone that has the tags)

set -euo pipefail

latest="$(git tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)"

if [ -n "$latest" ]; then
    range="$latest..HEAD"
else
    range="HEAD"
fi

subjects="$(git log --format=%s "$range"; printf '%s\n' "$@")"

if printf '%s\n' "$subjects" | grep -Eq '^[A-Za-z]+(\([^)]*\))?!:'; then
    major="${latest#v}"
    major="${major%%.*}"
    echo "$(( ${major:-0} + 1 )).0.0"
fi
