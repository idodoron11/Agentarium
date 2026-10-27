#!/usr/bin/env bash
# Keeps every skill installable and every Published skill Portable. Prints one line per violation.
# See docs/adr/0002-unpublished-skills-live-in-experimental-and-are-internal.md.
# Usage: scripts/check-skills.sh --check [root]
#   --check   exit 1 if any skill violates a rule; write nothing. root defaults to the repo.

set -euo pipefail

usage() {
    echo "Usage: $0 --check [root]" >&2
    exit 2
}

[ "${1:-}" = "--check" ] || usage
[ "$#" -le 2 ] || usage
ROOT="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -d "$ROOT/skills" ] || { echo "Missing skills folder: $ROOT/skills" >&2; exit 2; }

violations=0

report() {
    echo "$1" >&2
    violations=1
}

display_path() {
    echo "${1#"$ROOT/"}"
}

# Prints the frontmatter of a markdown file (the lines between the opening and closing ---).
frontmatter() {
    awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { print }' "$1"
}

# Prints the top-level frontmatter `name`, without surrounding quotes.
frontmatter_name() {
    frontmatter "$1" | sed -n -E "s/^name:[[:space:]]*[\"']?([^\"']*)[\"']?[[:space:]]*\$/\\1/p" | head -n 1
}

check_name() {
    local skill="$1" name
    name="$(frontmatter_name "$skill/SKILL.md")"
    if [ "$name" != "$(basename "$skill")" ]; then
        report "$(display_path "$skill/SKILL.md"): name \"$name\" does not match folder \"$(basename "$skill")\""
    fi
}

# Succeeds when the frontmatter has `internal: true` nested under `metadata:`.
is_internal() {
    frontmatter "$1" | awk '
        /^metadata:[[:space:]]*$/ { in_metadata = 1; next }
        /^[^[:space:]]/ { in_metadata = 0 }
        in_metadata && /^[[:space:]]+internal:[[:space:]]*true[[:space:]]*$/ { found = 1 }
        END { exit !found }'
}

check_internal_flag() {
    local skill="$1" published="$2"
    if [ "$published" = true ] && is_internal "$skill/SKILL.md"; then
        report "$(display_path "$skill/SKILL.md"): Published skill must not set metadata.internal"
    elif [ "$published" = false ] && ! is_internal "$skill/SKILL.md"; then
        report "$(display_path "$skill/SKILL.md"): Unpublished skill must set metadata.internal: true"
    fi
}

# Prints "<line>:<target>" for each markdown link outside fenced code blocks.
markdown_links() {
    awk '
        /^[[:space:]]*```/ { in_fence = !in_fence; next }
        in_fence { next }
        {
            rest = $0
            while (match(rest, /\]\([^)]*\)/)) {
                print NR ":" substr(rest, RSTART + 2, RLENGTH - 3)
                rest = substr(rest, RSTART + RLENGTH)
            }
        }' "$1"
}

# Prints the skill-relative path a link resolves to, failing if it climbs out of the skill folder.
resolve_in_skill() {
    local path="$1" part
    local -a stack=()
    local IFS=/
    for part in $path; do
        case "$part" in
            ""|.) ;;
            ..) [ "${#stack[@]}" -gt 0 ] || return 1; unset "stack[$((${#stack[@]} - 1))]" ;;
            *) stack+=("$part") ;;
        esac
    done
    echo "${stack[*]:-}"
}

check_links() {
    local skill="$1" file line target resolved reldir
    while IFS= read -r file; do
        reldir="${file#"$skill"}"
        reldir="${reldir%/*}"
        while IFS=: read -r line target; do
            target="${target%%[[:space:]]*}"
            target="${target#<}"
            target="${target%>}"
            target="${target%%#*}"
            target="${target%%\?*}"
            case "$target" in
                ""|[A-Za-z]*:*) continue ;;
                /*) report "$(display_path "$file"):$line: link escapes the skill folder: $target"; continue ;;
            esac
            if ! resolved="$(resolve_in_skill "$reldir/$target")"; then
                report "$(display_path "$file"):$line: link escapes the skill folder: $target"
            elif [ ! -e "$skill/$resolved" ]; then
                report "$(display_path "$file"):$line: link target not found: $target"
            fi
        done < <(markdown_links "$file")
    done < <(find "$skill" -type f -name '*.md' | sort)
}

# Generated shared-resource copies deliberately document per-agent tool prefixes and install paths.
is_generated_copy() {
    head -n 1 "$1" | grep -q '^<!-- Generated from shared/'
}

# report_matches <file> <extended regex> <message>
report_matches() {
    local file="$1" pattern="$2" message="$3" line
    while IFS=: read -r line _; do
        report "$(display_path "$file"):$line: $message"
    done < <(grep -n -I -E -e "$pattern" "$file" || true)
}

check_portable() {
    local file
    while IFS= read -r file; do
        is_generated_copy "$file" && continue
        report_matches "$file" '\.github/skills/' "Published skill uses agent install path .github/skills/"
        report_matches "$file" '\.claude/skills/' "Published skill uses agent install path .claude/skills/"
        report_matches "$file" '(^|[^[:alnum:]_])mcp_' "Published skill uses an mcp_ tool name"
    done < <(find "$1" -type f | sort)
}

# check_skill <skill folder> <true when Published, false when under .experimental>
check_skill() {
    local skill="$1" published="$2"
    if [ ! -f "$skill/SKILL.md" ]; then
        report "$(display_path "$skill"): missing SKILL.md"
        return
    fi
    check_name "$skill"
    check_internal_flag "$skill" "$published"
    check_links "$skill"
    if [ "$published" = true ]; then
        check_portable "$skill"
    fi
}

for skill in "$ROOT"/skills/*/ "$ROOT"/skills/.experimental/*/; do
    skill="${skill%/}"
    [ -d "$skill" ] || continue
    case "$skill" in
        */skills/.experimental) continue ;;
        */skills/.experimental/*) published=false ;;
        *) published=true ;;
    esac
    check_skill "$skill" "$published"
done

exit "$violations"
