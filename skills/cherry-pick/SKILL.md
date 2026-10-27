---
name: cherry-pick
description: "Backport a GitHub pull request to one or more branches by cherry-picking its commit(s). Use when: backporting a PR, porting changes to release branches, cherry-pick PR to branch, backport fix to CloudV, backport to release, port PR changes."
argument-hint: "GitHub PR URL or number, and target branch(es)"
---

# Cherry-Pick / Backport Skill

Backports a merged GitHub pull request to one or more target branches by cherry-picking its commit, pushing backport branches, and opening PRs.

## When to Use

- "Backport PR #N to Releases/X"
- "Port these changes to CloudV22, CloudV23"
- "Cherry-pick PR to release branch"

## Procedure

### Step 1 — Gather inputs

If not already provided, ask for:
1. **PR URL or number + repo** (e.g. `Varonis-Systems/ai-classifier#53`)
2. **Target branches** (e.g. `Releases/CloudV22`, `Releases/CloudV23`)

### Step 2 — Fetch PR details

Use `mcp_github_pull_request_read` (method: `get`) to retrieve:
- PR title, body, merge status
- `head.repo.full_name` → owner/repo
- Note the PR state (open or merged); cherry-pick works for botherged); cherry-pick only works for both

Also fetch the diff with method `get_diff` to understand the change scope.

### Step 3 — Find the cherry-pick commit

If the PR is **merged**, the head branch may be deleted. Find the **squash/merge commit** on the base branch:

```bash
git log --oneline origin/<base-branch> | head -10
```

Look for the commit whose message contains `(#<PR-number>)`. Note its short SHA.

If the PR is **open**, use the PR's `head.sha` directly — the branch still exists and the commits are available.

### Step 4 — Clone the repo via HTTPS

**Always clone via HTTPS** — SSH (port 22) may be blocked in some environments.

```bash
cd /tmp && rm -rf <repo>-backport
GIT_TERMINAL_PROMPT=0 git clone https://github.com/<owner>/<repo>.git <repo>-backport
cd <repo>-backport
git fetch origin
```

Large repos with LFS may take several minutes — wait patiently.

### Step 5 — Cherry-pick onto each target branch

For each target branch (e.g. `Releases/CloudV22`):

```bash
git checkout -b backport/<pr-number>-to-<short-branch> origin/<target-branch>
git cherry-pick <commit-sha>
git push origin backport/<pr-number>-to-<short-branch>
git checkout master   # or main — return to default branch before next iteration
```

If cherry-pick has **conflicts**:
- Show the conflicting files to the user
- Ask whether to resolve manually or skip that branch
- Do NOT push a branch with unresolved conflicts

A clean loop for multiple branches:

```bash
for branch in CloudV22 CloudV23 CloudV24; do
  git checkout -b backport/<pr-number>-to-$branch origin/Releases/$branch && \
  git cherry-pick <sha> && \
  git push origin backport/<pr-number>-to-$branch && \
  git checkout master || { echo "FAILED: $branch"; break; }
done
```

### Step 6 — Open backport PRs

For each successfully pushed branch, use `mcp_github_create_pull_request`:

- **title**: `[Backport <target-branch>] <original PR title>`
- **head**: `backport/<pr-number>-to-<short-branch>`
- **base**: `<target-branch>`
- **body**:
  ```
  Backport of #<pr-number> to `<target-branch>`.

  **Original PR:** #<pr-number> — <title>
  **Change:** <one-line summary of what changed>

  <!-- AGENTIC-WATERMARK team:.squad agents:coordinator repo:<owner>/<repo> -->
  ```

Report each created PR URL to the user.

### Step 7 — Clean up

**Always remove the cloned repo after all PRs are created.**

```bash
rm -rf /tmp/<repo>-backport
```

Confirm cleanup to the user.

## Notes & Gotchas

- **SSH timeout**: If `git clone git@github.com:...` hangs, switch to HTTPS immediately.
- **Commit not found locally**: The PR head SHA may not exist; always find the commit via `git log origin/<base-branch>` matching `(#N)`.
- **Conflicts**: Report conflicting files and ask the user before skipping a target branch.
- **LFS repos**: HTTPS clone may be slow (multi-GB); inform the user and wait.
- **Branch naming**: Use `backport/<pr-number>-to-<short-name>` (e.g. `backport/53-to-CloudV22`).
