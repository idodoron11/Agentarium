#!/usr/bin/env bash
# Runs scripts/sync-shared.sh against a copy of the fixture tree and asserts where it writes and what --check reports.
# Usage: tests/sync-shared.test.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="$ROOT/scripts/sync-shared.sh"
FIXTURE="$ROOT/tests/fixtures/sync-shared"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# One Published and one Unpublished (.experimental) skill use the same shared file.
export SYNC_SHARED_MAPPINGS="
NOTE.md open
NOTE.md draft
"

failures=0

check() {
    local name="$1" ok="$2"
    if [ "$ok" = true ]; then
        echo "ok   $name"
    else
        echo "FAIL $name"
        failures=$((failures + 1))
    fi
}

# fresh_tree: a writable copy of the fixture tree.
fresh_tree() {
    rm -rf "$WORKDIR/tree"
    cp -R "$FIXTURE" "$WORKDIR/tree"
}

fresh_tree
got="$("$SYNC" --check "$WORKDIR/tree" 2>&1)"
code=$?
want="$(printf '%s\n' 'Out of date: skills/open/NOTE.md (run scripts/sync-shared.sh)' \
    'Out of date: skills/.experimental/draft/NOTE.md (run scripts/sync-shared.sh)')"
[ "$code" -eq 1 ] && [ "$got" = "$want" ] && ok=true || ok=false
check "--check reports missing copies, including under .experimental" "$ok"

fresh_tree
got="$("$SYNC" "$WORKDIR/tree" 2>&1)"
want="$(printf '%s\n' 'Updated: skills/open/NOTE.md' 'Updated: skills/.experimental/draft/NOTE.md')"
[ "$got" = "$want" ] && ok=true || ok=false
check "sync reports both copies as updated" "$ok"

copy="$WORKDIR/tree/skills/.experimental/draft/NOTE.md"
expected="$(printf '%s\n\n' '<!-- Generated from shared/NOTE.md by scripts/sync-shared.sh. Do not edit; edit the source and re-run the script. -->'; cat "$FIXTURE/shared/NOTE.md")"
[ -f "$copy" ] && [ "$(cat "$copy")" = "$expected" ] && ok=true || ok=false
check "the shared file lands in the .experimental skill with the generated header" "$ok"

"$SYNC" --check "$WORKDIR/tree" >/dev/null 2>&1 && ok=true || ok=false
check "--check passes after syncing" "$ok"

echo "edited" >> "$copy"
"$SYNC" --check "$WORKDIR/tree" >/dev/null 2>&1 && ok=false || ok=true
check "--check fails when a copy under .experimental drifts" "$ok"

SYNC_SHARED_MAPPINGS="NOTE.md missing-skill" "$SYNC" --check "$WORKDIR/tree" >/dev/null 2>&1 && ok=false || ok=true
check "a mapping to an unknown skill fails" "$ok"

[ "$failures" -eq 0 ] || { echo "$failures sync-shared test(s) failed" >&2; exit 1; }
