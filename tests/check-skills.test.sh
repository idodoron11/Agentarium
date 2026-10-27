#!/usr/bin/env bash
# Runs scripts/check-skills.sh against each fixture skill tree and asserts its exit code and output.
# Usage: tests/check-skills.test.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/scripts/check-skills.sh"
FIXTURES="$ROOT/tests/fixtures/check-skills"

failures=0

# expect_check <fixture> <exit code> [expected output line]...
expect_check() {
    local fixture="$1" want_code="$2" got_code got want
    shift 2
    got="$("$CHECKER" --check "$FIXTURES/$fixture" 2>&1)"
    got_code=$?
    want="$(printf '%s\n' "$@")"
    [ "$#" -eq 0 ] && want=""
    if [ "$got_code" -eq "$want_code" ] && [ "$got" = "$want" ]; then
        echo "ok   $fixture"
    else
        echo "FAIL $fixture"
        echo "  expected exit $want_code, got $got_code"
        echo "  expected output: $want"
        echo "  actual output:   $got"
        failures=$((failures + 1))
    fi
}

expect_check valid-published 0
expect_check valid-unpublished 0
expect_check name-mismatch 1 \
    'skills/folder-name/SKILL.md: name "other-name" does not match folder "folder-name"'
expect_check link-escape 1 \
    'skills/leaky/SKILL.md:8: link escapes the skill folder: ../../README.md' \
    'skills/leaky/SKILL.md:8: link target not found: MISSING.md'
expect_check missing-internal 1 \
    'skills/.experimental/unflagged/SKILL.md: Unpublished skill must set metadata.internal: true'
expect_check published-internal 1 \
    'skills/flagged/SKILL.md: Published skill must not set metadata.internal'
expect_check mcp-name 1 \
    'skills/tooly/SKILL.md:8: Published skill uses an mcp_ tool name'
expect_check install-path 1 \
    'skills/pathy/SKILL.md:8: Published skill uses agent install path .claude/skills/'
expect_check generated-exempt 0

[ "$failures" -eq 0 ] || { echo "$failures check-skills test(s) failed" >&2; exit 1; }
