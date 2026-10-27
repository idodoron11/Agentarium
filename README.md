# Agentarium
A curated hub for AI agent resources, prompt engineering, and instruction sets.
Agentarium is a centralized repository designed for developers and AI enthusiasts working with intelligent coding assistants like Claude Code, Codex, and GitHub Copilot. It provides:

* Structured Prompts – Optimized templates for guiding AI agents effectively.
* Agent Configurations – Predefined setups for various coding and automation tasks.
* Instruction Files – Detailed workflows and best practices for building, deploying, and refining AI-driven solutions.

Whether you’re experimenting with prompt engineering, creating custom agents, or integrating AI into development pipelines, Agentarium serves as your go-to toolkit for innovation and productivity.

## Installing skills

Agentarium's Published skills (`review-pr`, `triage-pr-comments`, `pr-diff`, `cherry-pick`) install into Claude Code, GitHub Copilot, Codex, Cursor and other coding agents with [`npx skills`](https://github.com/vercel-labs/skills):

```sh
npx skills add idodoron11/Agentarium
```

* **Scope**: a project install (the default with `-y`) puts the skills in the current project (`.agents/skills/`, plus `.claude/skills/` for Claude Code). Add `-g` to install globally for your user instead (`~/.agents/skills/`, plus `~/.claude/skills/`).
* **Coding agents**: the command asks which coding agents to install for. Name them to skip the prompt, e.g. `-a claude-code github-copilot codex cursor`. Add `-y` to skip all prompts.
* **Updating**: `npx skills update` brings installed skills up to date (`-g` for global ones only, `-p` for project ones only).

CI runs `scripts/verify-install-channel.sh`, which installs this checkout globally into a throwaway home folder for Claude Code, GitHub Copilot, Codex and Cursor and checks what each receives, including that `--list` offers only the Published skills and that the installed `pr-diff` script runs. It runs on pull requests and on pushes to `main`.

## Shared skill resources

Some skills share a resource file (e.g. `PLATFORMS.md`). The single source lives in `shared/`, and `scripts/sync-shared.sh` copies it into each skill folder that uses it, so every skill stays self-contained when installed on its own ([ADR 0001](docs/adr/0001-shared-skill-resources-are-generated-copies.md)). Edit only the file in `shared/`, never a copy. Mappings name a skill; the script finds it under `skills/` or `skills/.experimental/`, and `tests/sync-shared.test.sh` checks both against a fixture tree.

Enable the pre-commit hook once per clone to regenerate the copies automatically:

```sh
git config core.hooksPath .githooks
```

CI runs `scripts/sync-shared.sh --check` and fails when a copy is out of date.

The same hook and CI also run the skill checker, `scripts/check-skills.sh --check [root]`, which prints one line per violation and exits non-zero if any are found. It keeps every skill installable and every Published skill Portable: the frontmatter `name` equals the folder name, every relative link stays inside the skill's folder, Published skills contain no agent install paths (`.github/skills/`, `.claude/skills/`) or `mcp_` tool names (as whole words, so `xmcp_` is fine; the generated shared copies are exempt), and `metadata.internal: true` is set exactly on skills under `.experimental`. CI also runs the checker's fixture tests, `tests/check-skills.test.sh`.

## Versioning

Every push to `main` releases a new `vX.Y.0` tag and GitHub Release for the whole repo. A `feat` or breaking change (`!` / `BREAKING CHANGE`) bumps the major version; anything else bumps the minor version. PR titles must be Conventional Commits, and PRs are squash-merged, and the PR check previews the release from the PR title alone (`scripts/breaking-release-tag.sh --title`, tested by `tests/breaking-release-tag.test.sh`). See [ADR 0003](docs/adr/0003-every-push-to-main-is-a-major-or-minor-release.md).

## Unpublished skills

Skills not offered by default live in `skills/.experimental/<name>/` and set `metadata.internal: true` ([ADR 0002](docs/adr/0002-unpublished-skills-live-in-experimental-and-are-internal.md)). The install command above skips them; opt in to one by name with `-s <name>` (currently `refactor`, `mypy-check`, `daily-standup`), for example `npx skills add idodoron11/Agentarium -s daily-standup`.
