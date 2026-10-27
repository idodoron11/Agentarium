---
name: triage-pr-comments
description: "Triage unresolved review comments on a GitHub or Azure DevOps pull request. Use when the user shares a PR URL or ID and asks to triage, review, or address open review threads."
argument-hint: "GitHub PR URL (https://github.com/org/repo/pull/N) or ADO PR ID + repo name"
---

# Triage PR Review Comments

**Triage decision** — every unresolved thread gets one of three: **fix**, **explain**, or **dismiss**.

## Step 1 — Fetch unresolved threads

Detect the platform from the URL or argument, then pull all open threads:

**GitHub** — `mcp_github_mcp_se_pull_request_read` with `method: get_review_comments`. Keep threads where `is_resolved: false`.

**Azure DevOps** — `mcp_azure_devops__repo_pull_request_thread` with `action: list` and `status: Active`.

Also fetch the PR description (`method: get`) and diff (`method: get_diff`) for code context.

For each open thread, record: `{threadId, nodeId, author, body, file, line}`.

_Completion: you hold the full list — no thread skipped._

## Step 2 — Make triage decisions

For each thread, read the actual code at the referenced file and line (fetch the file from the PR branch). Assign one triage decision:

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

## Step 3 — Gate

Present the table and await explicit user approval. The user may override any triage decision before approving.

_Completion: the user has explicitly approved each thread._

## Step 4 — Execute

Work through each thread in the order of: fix decisions first (so replies can reference the commit SHA), then explain and dismiss decisions.

**fix decision**
1. Edit the code and commit with a descriptive message.
2. Record the commit SHA.
3. Post a reply referencing the commit: _"Fixed in commit `abc1234`."_

**explain decision**
1. Post a reply stating clearly why no code change is needed.

**dismiss decision**
1. Post a reply stating why the comment does not apply.

After replying, resolve/close the thread:
- **GitHub** — `mcp_github_mcp_se_pull_request_review_write` with `method: resolve_thread` and the thread's node ID.
- **ADO** — `mcp_azure_devops__repo_pull_request_thread_write` with `action: update_status`; use `Fixed` for fix/explain and `WontFix` for dismiss.

_Completion: every thread from Step 1 is resolved on the platform. Verify by re-fetching — no Active/unresolved threads remain._
