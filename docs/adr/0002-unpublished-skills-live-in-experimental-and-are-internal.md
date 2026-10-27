# Unpublished skills live in skills/.experimental and are marked internal

Skills that should not ship by default (personal or draft) live in `skills/.experimental/<name>/` and set `metadata.internal: true` in their frontmatter. `npx skills` still discovers that folder, but skips internal skills unless the user names them (`npx skills add idodoron11/Agentarium -s <name>`) or sets `INSTALL_INTERNAL_SKILLS=1`. This keeps Unpublished skills visibly separate while letting the author install them through the same channel as Published ones.

## Considered Options

- **A top-level `unpublished/` folder outside the scanned paths**: no frontmatter flag can leak a skill into a default install, but opting in needs `--full-depth` or a local clone path instead of the standard command.
- **One `skills/` folder, distinguished only by `metadata.internal`**: the standard install command works, but you can't tell which skills ship by looking at the folders.

## Consequences

Publishing a skill means moving its folder from `skills/.experimental/` to `skills/` and removing `metadata.internal`. CI enforces that both happen together. `scripts/sync-shared.sh` mappings must handle skills under `.experimental/`.
