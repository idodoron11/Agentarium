# Source this file to find skill folders. A Published skill is a top-level folder of skills/, an Unpublished
# one a folder of skills/.experimental/; see docs/adr/0002-unpublished-skills-live-in-experimental-and-are-internal.md.

# skill_dir <root> <skill name>: prints the skill's folder, failing if there is none.
skill_dir() {
    local candidate
    for candidate in "$1/skills/$2" "$1/skills/.experimental/$2"; do
        if [ -d "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

# published_skills <root> / unpublished_skills <root>: print the skill names, one per line.
published_skills() {
    find "$1/skills" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -exec basename {} \; | sort
}

unpublished_skills() {
    [ ! -d "$1/skills/.experimental" ] || find "$1/skills/.experimental" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}
