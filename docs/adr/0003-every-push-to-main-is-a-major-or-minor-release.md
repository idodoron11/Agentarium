# Every push to main releases a new major or minor version

The whole repo carries one version, stored only as a `vX.Y.0` git tag and a GitHub Release with generated notes. Every push or merge to `main` creates a release, whatever it changed. The bump comes from the Conventional Commits type of the highest-ranked commit in the push: `feat` or `!`/`BREAKING CHANGE` → major; anything else, including messages that aren't conventional → minor. Patch is always 0. PRs must be squash-merged so their conventional title becomes the commit that decides the bump.

## Considered Options

- **Standard semver mapping** (`feat` → minor, `fix` → patch): rejected. For skills, a new capability changes how the agent behaves, which the author treats as major.
- **Bump only when Published skills change**: rejected in favor of a simple rule with no path filtering.
- **Per-skill versions in `metadata.version`**: rejected. Users install the set, and per-skill bookkeeping would need CI to commit back to `main`.
- **A committed `VERSION` file or changelog**: rejected. It needs a bot that can push past branch protection, and it creates release-commit loops.

## Consequences

Version numbers grow quickly and don't signal compatibility in the usual semver sense. An installed skill folder doesn't know its own version; the tag on the source repo is the only record. `npx skills update` ignores versions and tracks folder hashes.
