#!/usr/bin/env bash
# Prints the next version for a release, for the tag action's `custom_tag` input. See docs/adr/0003.
# The tag action's commit analyzer ignores the Conventional Commits "!" breaking marker, so this forces the major bump.
# Run inside a clone that has the tags.
#
# Usage: scripts/breaking-release-tag.sh
#   Push mode: prints the next major version (X.0.0) when a commit since the latest vX.Y.Z tag carries a "!"
#   breaking marker; prints nothing otherwise, leaving the bump to the tag action.
# Usage: scripts/breaking-release-tag.sh --title <pull request title>
#   Title mode: previews the squash merge. The title is the only commit message, so it alone decides the bump:
#   `feat`, a "!" marker or BREAKING CHANGE prints the next major (X.0.0), anything else the next minor (X.Y.0).

set -euo pipefail

usage() {
    echo "Usage: $0 [--title <pull request title>]" >&2
    exit 2
}

latest="$(git tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)"
version="${latest#v}"
version="${version:-0.0.0}"
major="${version%%.*}"
minor="${version#*.}"
minor="${minor%%.*}"

# The "!" marker, as in `feat!:` or `fix(api)!:`.
BREAKING_MARKER='^[A-Za-z]+(\([^)]*\))?!:'

preview_squash_commit() {
    local title="$1"
    if printf '%s\n' "$title" | grep -Eq "$BREAKING_MARKER|^feat(\([^)]*\))?:|BREAKING[ -]CHANGE"; then
        echo "$((major + 1)).0.0"
    else
        echo "${major}.$((minor + 1)).0"
    fi
}

next_major_if_breaking_since_latest_tag() {
    local range="HEAD"
    [ -z "$latest" ] || range="$latest..HEAD"
    if git log --format=%s "$range" | grep -Eq "$BREAKING_MARKER"; then
        echo "$((major + 1)).0.0"
    fi
}

case "$#:${1:-}" in
    0:) next_major_if_breaking_since_latest_tag ;;
    2:--title) preview_squash_commit "$2" ;;
    *) usage ;;
esac
