#!/usr/bin/env bash
# Verifies the install channel: runs a real `npx skills add` of this checkout into a throwaway HOME for
# Claude Code, GitHub Copilot, Codex and Cursor, then asserts what each coding agent receives.
# See docs/adr/0002-unpublished-skills-live-in-experimental-and-are-internal.md.
# Usage: scripts/verify-install-channel.sh
#   VERIFY_INSTALL_WORKDIR   optional scratch directory (created if missing, never the real HOME or the checkout)
#                            instead of a fresh mktemp directory; its contents are removed on exit

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AGENTS="claude-code github-copilot codex cursor"
AGENT_NAMES="Claude Code,GitHub Copilot,Codex,Cursor"
PUBLISHED="cherry-pick pr-diff review-external-pr triage-pr-comments"
OPT_IN="daily-standup"

# A global install keeps one canonical copy in ~/.agents/skills, which GitHub Copilot, Codex and
# Cursor read directly; Claude Code gets symlinks into ~/.claude/skills.
CANONICAL_DIR=".agents/skills"
CLAUDE_DIR=".claude/skills"

failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }
pass() { echo "ok:   $*"; }

WORKDIR="${VERIFY_INSTALL_WORKDIR:-$(mktemp -d)}"
mkdir -p "$WORKDIR"
WORKDIR="$(cd "$WORKDIR" && pwd)"
case "$WORKDIR" in
    "$ROOT"|"$ROOT"/*|"$HOME"|"/") echo "Refusing to use $WORKDIR as scratch directory" >&2; exit 2 ;;
esac
trap 'rm -rf "$WORKDIR"' EXIT

FAKE_HOME="$WORKDIR/home"
mkdir -p "$FAKE_HOME" "$WORKDIR/cwd"

checkout_state() { git -C "$ROOT" status --porcelain --ignored 2>/dev/null || true; }
checkout_before="$(checkout_state)"

# Runs the install with the throwaway HOME, from outside the checkout, printing the machine-readable result.
install_skills() {
    (cd "$WORKDIR/cwd" && HOME="$FAKE_HOME" CI=1 npx --yes skills add "$ROOT" -g -y --json "$@") 2>"$WORKDIR/install.log" \
        || { cat "$WORKDIR/install.log" >&2; echo "FAIL: npx skills add $* exited non-zero" >&2; exit 1; }
}

# Checks that every installed skill in the JSON result targets all four coding agents.
assert_targets_all_agents() {
    local result="$1" label="$2"
    if printf '%s' "$result" | node -e '
        const expected = process.argv[1].split(",");
        const installed = JSON.parse(require("fs").readFileSync(0, "utf8"));
        const bad = installed.filter(s => s.status !== "installed" || expected.some(a => !s.agents.includes(a)));
        if (installed.length === 0 || bad.length) { console.error(JSON.stringify(bad)); process.exit(1); }
    ' "$AGENT_NAMES"; then
        pass "$label: every skill installed for $AGENT_NAMES"
    else
        fail "$label: a skill was not installed for all of $AGENT_NAMES"
    fi
}

source_dir() {
    local candidate
    for candidate in "$ROOT/skills/$1" "$ROOT/skills/.experimental/$1"; do
        [ -d "$candidate" ] && { echo "$candidate"; return 0; }
    done
    echo "FAIL: no source folder for skill $1" >&2
    return 1
}

# Asserts the folder lists exactly the given skill names (a skills folder holds nothing else).
assert_exact_skills() {
    local folder="$1" label="$2"; shift 2
    local expected actual
    expected="$(printf '%s\n' "$@" | sort)"
    actual="$(ls -1 "$folder" 2>/dev/null | sort)"
    if [ "$expected" = "$actual" ]; then
        pass "$label contains exactly: $*"
    else
        fail "$label differs; expected [$(echo $expected)] got [$(echo $actual)]"
    fi
}

# Asserts the installed skill has the same files, with the same content, as its source folder.
assert_complete() {
    local skill="$1" folder="$2" label="$3" src
    src="$(source_dir "$skill")"
    if diff -r "$src/" "$folder/$skill/" >/dev/null; then
        pass "$label/$skill matches its source folder"
    else
        fail "$label/$skill differs from its source folder"
        diff -r "$src/" "$folder/$skill/" >&2 || true
    fi
}

# --- Default install: only the Published skills ---------------------------------------------------
# shellcheck disable=SC2086
result="$(install_skills -a $AGENTS)"
assert_targets_all_agents "$result" "default install"

# Names are derived from the source tree so a newly added Unpublished skill is covered automatically.
UNPUBLISHED="$(ls -1 "$ROOT/skills/.experimental")"

for folder in "$CANONICAL_DIR" "$CLAUDE_DIR"; do
    assert_exact_skills "$FAKE_HOME/$folder" "~/$folder" $PUBLISHED
    for skill in $PUBLISHED; do
        assert_complete "$skill" "$FAKE_HOME/$folder" "~/$folder"
    done
done

for skill in $UNPUBLISHED; do
    for folder in "$CANONICAL_DIR" "$CLAUDE_DIR"; do
        [ -e "$FAKE_HOME/$folder/$skill" ] && fail "Unpublished skill $skill installed by default in ~/$folder"
    done
done
pass "no Unpublished skill ($(echo $UNPUBLISHED)) installed by default"

# Shared resources and scripts are part of "every file", but name them so a regression is explicit.
for skill in review-external-pr triage-pr-comments; do
    [ -f "$FAKE_HOME/$CANONICAL_DIR/$skill/PLATFORMS.md" ] || fail "$skill is missing PLATFORMS.md"
done
for script in pr-diff.sh pr-diff.ps1; do
    [ -f "$FAKE_HOME/$CANONICAL_DIR/pr-diff/scripts/$script" ] || fail "pr-diff is missing scripts/$script"
done
[ -x "$FAKE_HOME/$CANONICAL_DIR/pr-diff/scripts/pr-diff.sh" ] || fail "pr-diff/scripts/pr-diff.sh is not executable"

# --- Opt-in: an Unpublished skill by name ----------------------------------------------------------
# shellcheck disable=SC2086
result="$(install_skills -s $OPT_IN -a $AGENTS)"
assert_targets_all_agents "$result" "opt-in install"

for folder in "$CANONICAL_DIR" "$CLAUDE_DIR"; do
    assert_exact_skills "$FAKE_HOME/$folder" "~/$folder after opting in" $PUBLISHED $OPT_IN
    assert_complete "$OPT_IN" "$FAKE_HOME/$folder" "~/$folder"
done

# --- The install touched neither the checkout nor anything outside the throwaway HOME ---------------
if [ "$checkout_before" = "$(checkout_state)" ]; then
    pass "checkout left untouched"
else
    fail "install modified the checkout"
fi

if [ "$failures" -ne 0 ]; then
    echo "$failures check(s) failed" >&2
    exit 1
fi
echo "Install channel verified"
