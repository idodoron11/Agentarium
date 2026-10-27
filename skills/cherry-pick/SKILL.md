---
name: cherry-pick
description: "Backport a GitHub pull request to one or more branches by cherry-picking its commit(s). Use when: backporting a PR, porting changes to release branches, cherry-picking a PR onto a branch, porting PR changes to another branch."
argument-hint: "GitHub PR URL or number, and target branch(es)"
---

# Cherry-Pick / Backport Skill

Backports a merged GitHub pull request to one or more target branches by cherry-picking its commit, pushing backport branches, and opening PRs.

## When to Use

- "Backport PR #N to release/1.x"
- "Port these changes to release/1.x and release/2.x"
- "Cherry-pick PR to a release branch"

## Procedure

### Step 1 — Gather inputs

If not already provided, ask for:
1. **PR URL or number + repo** (e.g. `owner/repo#123`)
2. **Target branches** (e.g. `release/1.x`, `release/2.x`)

### Step 2 — Fetch PR details

Retrieve the PR details with `gh`:

```bash
gh pr view <pr-number> --repo <owner>/<repo> --json title,body,state,baseRefName,headRefOid,mergeCommit
```

- Note the title, body and state (open or merged); cherry-pick works for both.
- `mergeCommit.oid` is the merge commit once the PR is merged; `headRefOid` is the head commit.

Fetch the diff to understand the change scope:

```bash
gh pr diff <pr-number> --repo <owner>/<repo>
```

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

For each target branch (e.g. `release/1.x`):

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
for branch in 1.x 2.x 3.x; do
  git checkout -b backport/<pr-number>-to-$branch origin/release/$branch && \
  git cherry-pick <sha> && \
  git push origin backport/<pr-number>-to-$branch && \
  git checkout master || { echo "FAILED: $branch"; break; }
done
```

### Step 6 — Open backport PRs

For each successfully pushed branch, create the PR with `gh pr create`:

```bash
gh pr create --repo <owner>/<repo> \
  --base <target-branch> \
  --head backport/<pr-number>-to-<short-branch> \
  --title "[Backport <target-branch>] <original PR title>" \
  --body "<body>"
```

The body:

```
Backport of #<pr-number> to `<target-branch>`.

**Original PR:** #<pr-number> — <title>
**Change:** <one-line summary of what changed>
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
- **Branch naming**: Use `backport/<pr-number>-to-<short-name>` (e.g. `backport/123-to-1.x`).
