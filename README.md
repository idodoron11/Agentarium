# Agentarium
A curated hub for AI agent resources, prompt engineering, and instruction sets.
Agentarium is a centralized repository designed for developers and AI enthusiasts working with intelligent coding assistants like Claude Code, Codex, and GitHub Copilot. It provides:

* Structured Prompts – Optimized templates for guiding AI agents effectively.
* Agent Configurations – Predefined setups for various coding and automation tasks.
* Instruction Files – Detailed workflows and best practices for building, deploying, and refining AI-driven solutions.

Whether you’re experimenting with prompt engineering, creating custom agents, or integrating AI into development pipelines, Agentarium serves as your go-to toolkit for innovation and productivity.

## Shared skill resources

Some skills share a resource file (e.g. `PLATFORMS.md`). The single source lives in `shared/`, and `scripts/sync-shared.sh` copies it into each skill folder that uses it, so every skill stays self-contained when installed on its own ([ADR 0001](docs/adr/0001-shared-skill-resources-are-generated-copies.md)). Edit only the file in `shared/`, never a copy. Mappings name a skill; the script finds it under `skills/` or `skills/.experimental/`.

Enable the pre-commit hook once per clone to regenerate the copies automatically:

```sh
git config core.hooksPath .githooks
```

CI runs `scripts/sync-shared.sh --check` and fails when a copy is out of date.

## Unpublished skills

Skills not offered by default live in `skills/.experimental/<name>/` and set `metadata.internal: true` ([ADR 0002](docs/adr/0002-unpublished-skills-live-in-experimental-and-are-internal.md)). `npx skills add idodoron11/Agentarium` skips them; install one explicitly with `-s <name>` (currently `refactor`, `mypy-check`, `daily-standup`).
