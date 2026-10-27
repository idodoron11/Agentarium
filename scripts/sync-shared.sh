#!/usr/bin/env bash
# Copies each shared resource into the skill folders that use it, so every skill stays self-contained.
# See docs/adr/0001-shared-skill-resources-are-generated-copies.md.
# Usage: scripts/sync-shared.sh [--check] [root]
#   --check   exit 1 if any generated copy is missing or differs from its source; write nothing
#   root      defaults to the repo; SYNC_SHARED_MAPPINGS replaces the MAPPINGS below (used by the fixture tests)

set -euo pipefail

usage() {
    echo "Usage: $0 [--check] [root]" >&2
    exit 2
}

check=false
if [ "${1:-}" = "--check" ]; then
    check=true
    shift
fi
[ "$#" -le 1 ] || usage
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=skill-folders.sh
source "$(dirname "${BASH_SOURCE[0]}")/skill-folders.sh"

# "<source under shared/> <skill name>", one pair per line. A skill is found under skills/ (Published)
# or skills/.experimental/ (Unpublished); see docs/adr/0002-unpublished-skills-live-in-experimental-and-are-internal.md.
MAPPINGS="${SYNC_SHARED_MAPPINGS:-
PLATFORMS.md review-pr
PLATFORMS.md triage-pr-comments
}"

render() {
    printf '<!-- Generated from shared/%s by scripts/sync-shared.sh. Do not edit; edit the source and re-run the script. -->\n\n' "$1"
    cat "$ROOT/shared/$1"
}

stale=0
while read -r source skill; do
    [ -z "$source" ] && continue
    if ! dir="$(skill_dir "$ROOT" "$skill")"; then
        echo "Missing skill folder: skills/$skill or skills/.experimental/$skill" >&2
        exit 1
    fi
    target="$dir/$source"
    shown="${target#"$ROOT/"}"
    if render "$source" | cmp -s - "$target"; then
        continue
    fi
    if [ "$check" = true ]; then
        echo "Out of date: $shown (run scripts/sync-shared.sh)" >&2
        stale=1
    else
        render "$source" > "$target"
        echo "Updated: $shown"
    fi
done <<< "$MAPPINGS"

exit "$stale"
