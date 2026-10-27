#!/usr/bin/env bash
# Runs scripts/breaking-release-tag.sh in throwaway git repos and asserts what it prints.
# Usage: tests/breaking-release-tag.test.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/breaking-release-tag.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

failures=0

# new_repo <name> [tag]: an empty repo, optionally with a first commit tagged <tag>.
new_repo() {
    local repo="$WORKDIR/$1"
    git init -q "$repo"
    git -C "$repo" config user.name test
    git -C "$repo" config user.email test@example.com
    git -C "$repo" config commit.gpgsign false
    if [ -n "${2:-}" ]; then
        git -C "$repo" commit -q --allow-empty -m "chore: initial"
        git -C "$repo" tag "$2"
    fi
    echo "$repo"
}

commit() {
    git -C "$1" commit -q --allow-empty -m "$2"
}

# expect_output <name> <repo> <expected output> [script argument]...
expect_output() {
    local name="$1" repo="$2" want="$3" got
    shift 3
    got="$(cd "$repo" && "$SCRIPT" "$@" 2>&1)"
    if [ "$got" = "$want" ]; then
        echo "ok   $name"
    else
        echo "FAIL $name"
        echo "  expected: [$want]"
        echo "  actual:   [$got]"
        failures=$((failures + 1))
    fi
}

# --- Push mode: no arguments; only "!" breaking markers in commits since the latest tag matter ---
repo="$(new_repo push-quiet v1.4.0)"
commit "$repo" "fix: something"
expect_output "push: no breaking marker prints nothing" "$repo" ""

repo="$(new_repo push-breaking v1.4.0)"
commit "$repo" "fix: something"
commit "$repo" "refactor(api)!: drop the old endpoint"
expect_output "push: '!' commit since the tag prints the next major" "$repo" "2.0.0"

repo="$(new_repo push-old-breaking v1.4.0)"
git -C "$repo" commit -q --allow-empty -m "feat!: old break"
git -C "$repo" tag v2.0.0
commit "$repo" "fix: later"
expect_output "push: '!' commit before the latest tag is ignored" "$repo" ""

repo="$(new_repo push-no-tag)"
commit "$repo" "feat!: first"
expect_output "push: no tag yet prints 1.0.0" "$repo" "1.0.0"

# --- Title mode: the PR title is the squash commit; the PR's own commits are ignored ---
repo="$(new_repo title-feat v1.4.0)"
commit "$repo" "fix: only a fix in the branch"
expect_output "title: feat is a major" "$repo" "2.0.0" --title "feat: add a skill"

expect_output "title: feat with a scope is a major" "$repo" "2.0.0" --title "feat(cherry-pick): add a skill"
expect_output "title: '!' is a major" "$repo" "2.0.0" --title "fix!: rename a skill"
expect_output "title: scoped '!' is a major" "$repo" "2.0.0" --title "docs(readme)!: rewrite"
expect_output "title: BREAKING CHANGE is a major" "$repo" "2.0.0" --title "fix: BREAKING CHANGE drop a flag"
expect_output "title: fix is a minor" "$repo" "1.5.0" --title "fix: typo"
expect_output "title: chore is a minor" "$repo" "1.5.0" --title "chore: tidy"
expect_output "title: non-conventional is a minor" "$repo" "1.5.0" --title "Update the README"
expect_output "title: feat without a colon is a minor" "$repo" "1.5.0" --title "feat add a skill"
expect_output "title: feature is not feat" "$repo" "1.5.0" --title "feature: add a skill"

repo="$(new_repo title-branch-breaking v1.4.0)"
commit "$repo" "feat!: breaking commit in the branch"
expect_output "title: a '!' commit in the branch is ignored" "$repo" "1.5.0" --title "fix: only a fix"

repo="$(new_repo title-no-tag)"
commit "$repo" "chore: first"
expect_output "title: no tag yet, minor prints 0.1.0" "$repo" "0.1.0" --title "fix: first"
expect_output "title: no tag yet, major prints 1.0.0" "$repo" "1.0.0" --title "feat: first"

repo="$(new_repo title-ignores-pre-release-tags v1.4.0)"
git -C "$repo" tag v1.9.0-rc.1
git -C "$repo" tag latest
expect_output "title: only vX.Y.Z tags count" "$repo" "1.5.0" --title "fix: x"

repo="$(new_repo usage v1.4.0)"
got_code=0
(cd "$repo" && "$SCRIPT" "feat!: stray argument" >/dev/null 2>&1) || got_code=$?
if [ "$got_code" -eq 2 ]; then
    echo "ok   usage: stray argument is rejected"
else
    echo "FAIL usage: stray argument exited $got_code, expected 2"
    failures=$((failures + 1))
fi

[ "$failures" -eq 0 ] || { echo "$failures breaking-release-tag test(s) failed" >&2; exit 1; }
