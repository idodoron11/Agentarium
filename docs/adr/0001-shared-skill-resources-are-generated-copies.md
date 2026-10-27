# Shared skill resources are generated copies committed in each skill folder

`review-pr` and `triage-pr-comments` share their GitHub/Azure DevOps platform recipes. The single source lives in `shared/`, and `scripts/sync-shared.sh` copies it into each consuming skill folder; the copies are committed, marked generated, and enforced by a pre-commit hook and a CI `--check`. Every skill must stay self-contained: a SKILL.md links only to files inside its own folder.

## Considered Options

- **Link outside the skill folder** (`../../shared/PLATFORMS.md`): the Agent Skills spec resolves references from the skill root, and `npx skills add` copies only the skill's own folder.
- **Install-time copy**: no installer (Claude Code plugins, Copilot CLI plugins, `npx skills`) offers an install hook or a files/copy manifest field; Cursor, Codex and VS Code have no installer at all.
- **In-repo symlinks**: preserved by Claude Code plugins, but `npx skills add` skips symlinks that escape the skill folder, and Windows checkouts may not materialize them.
- **CI-built `dist` branch** with a duplicate-free `main`: every installer can target a ref, but the default install (`npx skills add owner/repo`, plain clone) would get broken skills.
- **A third "platform" skill loaded by name**: no harness or the spec supports skill-to-skill dependencies.

## Consequences

Generated copies appear in the repo; `.gitattributes` marks them `linguist-generated` so GitHub collapses them in diffs. Edit only `shared/`; editing a copy fails CI.
