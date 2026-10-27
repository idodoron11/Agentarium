---
name: triage-pr-comments
description: "Triage unresolved review comments on a GitHub or Azure DevOps pull request. Use when the user shares a PR URL or number and asks to triage, review, or address open review threads."
argument-hint: "PR URL (GitHub or Azure DevOps), or a PR number from inside the PR's checkout"
---

# Triage PR Review Comments

**Triage decision** — every unresolved thread gets one of three: **fix**, **explain**, or **dismiss**.

The run works in a local checkout of the PR's head branch: fixes are committed and pushed from it. Every reply posted ends with the signer line `*Triaged by <signer>*` (*Signer* in [PLATFORMS.md](PLATFORMS.md)).

## Step 1 — Resolve the PR and tooling

Open [PLATFORMS.md](PLATFORMS.md). Identify the PR:

- **URL**: the platform and repository come from the URL forms in PLATFORMS.md.
- **PR number only**: take them from `git remote get-url origin`. GitHub remotes contain `github.com[:/]<owner>/<repo>`; Azure DevOps remotes contain `dev.azure.com/<org>/<project>/_git/<repo>`, `ssh.dev.azure.com:v3/<org>/<project>/<repo>`, or `<org>.visualstudio.com/<project>/_git/<repo>`. Any other remote: ask the user for the PR URL.

Read that platform's section only, and choose a **tier** per *Choosing a tier*.

_Completion: a read call through the chosen tier returned the PR's metadata, or the user has setup guidance and the run has stopped._

## Step 2 — Fetch the PR and its open threads

Through the chosen tier, retrieve the PR's title, description, state, head branch, head commit SHA, and diff (*Read*), and every review thread (*Threads*). A merged, closed, or abandoned PR ends the run with a one-line note.

Verify the checkout before any triage: the local repository points at the PR's repository (for a fork PR, its head repository), the current branch is the PR's head branch, and after a `git fetch`, `git merge-base --is-ancestor <head SHA> HEAD` succeeds. On a mismatch, stop and give the user the checkout command (`gh pr checkout <n>` or `az repos pr checkout --id <n>`).

For each open thread (per *Thread status*), record: thread ID (on GitHub, the node ID and the first comment's numeric ID), author, original comment, replies, file, line.

_Completion: the checkout is verified and you hold every open thread — no thread skipped._

## Step 3 — Make triage decisions

For each thread, read the actual code at the referenced file and line in the local checkout. Assign one triage decision:

- **fix** — the comment identifies a genuine defect, inconsistency, or clear improvement
- **explain** — the comment raises a valid question but no code change is warranted; a reply closes it
- **dismiss** — the comment is factually wrong, based on a misread, or targets code outside the PR's scope

**Every comment must be explained regardless of triage decision:**
- For **fix**: describe the issue clearly (what is wrong and why it matters) and propose a concrete solution.
- For **explain** or **dismiss**: state explicitly why the comment is not actionable — wrong assumption, misread code, out of scope, etc.

Present every thread in a single table before pausing:

| # | Location | Author | Decision | Explanation | Proposed action |
|---|----------|--------|---------|-------------|----------------|
| 1 | `File.cs:42` — _"..."_ | @reviewer | fix | `_foo` conflicts with the naming convention used on all sibling fields; it will confuse readers and break tooling that relies on the prefix. | Rename `_foo` → `_bar`; commit |
| 2 | `File.cs:109` — _"..."_ | @reviewer | dismiss | The reviewer assumed a standard lambda, but a capturing lambda is required here because `ctx` is captured from the outer scope and cannot be passed as a parameter at this call site. | Reply explaining the capture requirement |

_Completion: every unresolved thread has a row with a non-empty Explanation cell._

## Step 4 — Gate

Present the table and await explicit user approval. The user may override any triage decision before approving.

_Completion: the user has explicitly approved each thread._

## Step 5 — Execute

Work through the approved threads in three phases, so every reply that cites a commit cites a pushed one.

1. **Fix**: for each fix decision, edit the code, commit with a descriptive message, and record the SHA.
2. **Push**: `git push` once, after all fixes. If the push fails, stop and report: post no replies.
3. **Reply and close**: through *Thread replies* in PLATFORMS.md, post one reply per thread ending with the signer line, then close the thread with the matching *Thread status* operation:

| Triage decision | Reply | Close as |
|---|---|---|
| **fix** | _"Fixed in commit `abc1234`."_ | fixed |
| **explain** | Why no code change is needed. | by design |
| **dismiss** | Why the comment does not apply. | won't fix |

_Completion: re-fetching the threads shows every thread from Step 2 closed with its reply; any failed reply or status change is reported with its text so the user can finish by hand._
