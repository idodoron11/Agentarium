#!/usr/bin/env bash
# Copies each shared resource into the skill folders that use it, so every skill stays self-contained.
# See docs/adr/0001-shared-skill-resources-are-generated-copies.md.
# Usage: scripts/sync-shared.sh [--check]
#   --check   exit 1 if any generated copy is missing or differs from its source; write nothing

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# "<source under shared/> <skill name>", one pair per line. A skill is found under skills/ (Published)
# or skills/.experimental/ (Unpublished); see docs/adr/0002-unpublished-skills-live-in-experimental-and-are-internal.md.
MAPPINGS="
PLATFORMS.md review-external-pr
PLATFORMS.md triage-pr-comments
"

check=false
case "${1:-}" in
    --check) check=true ;;
    "") ;;
    *) echo "Usage: $0 [--check]" >&2; exit 2 ;;
esac

skill_dir() {
    local candidate
    for candidate in "$ROOT/skills/$1" "$ROOT/skills/.experimental/$1"; do
        if [ -d "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

render() {
    printf '<!-- Generated from shared/%s by scripts/sync-shared.sh. Do not edit; edit the source and re-run the script. -->\n\n' "$1"
    cat "$ROOT/shared/$1"
}

stale=0
while read -r source skill; do
    [ -z "$source" ] && continue
    if ! dir="$(skill_dir "$skill")"; then
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
