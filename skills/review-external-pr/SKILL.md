---
name: review-external-pr
description: "Review a GitHub or Azure DevOps PR from its URL, draft inline findings and a suggested verdict for your approval, then post them signed by the reviewing agent."
argument-hint: "Full PR URL (GitHub or Azure DevOps)"
disable-model-invocation: true
---

# External PR Review

Review the pull request at the URL the user provided. The run has two halves: build a **draft** review locally (findings plus a suggested **verdict**), then post only the **approved set** and the confirmed verdict once the user signs off.

**Signer**: the name of the agent product running this skill (e.g. `Copilot`, `Claude Code`, `Cursor`). Every posted comment ends with `*Reviewed by <signer>*`.

## Step 1 — Resolve tooling

Identify the platform from the URL (`github.com/<owner>/<repo>/pull/<n>` or `dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<n>`; `<org>.visualstudio.com` is Azure DevOps too). Open [PLATFORMS.md](PLATFORMS.md) and read the section for that platform only.

Pick the first **tier** that passes its check in PLATFORMS.md: CLI → MCP → guidance. A tier that is present but fails its check (unauthenticated, missing extension, wrong org) is misconfigured: fall through to the next tier, and if none works, give the user the guidance for the failing tier and stop.

Done when: a read call through the chosen tier returned the PR's metadata, or the user has setup guidance and the run has stopped.

## Step 2 — Fetch the PR

Through the chosen tier, retrieve: title, description, author (on GitHub, also the authenticated user, for the self-authored check under Verdict), base branch, head commit SHA, the list of changed files, and the full diff.

Done when: you hold a diff for every changed file in the list.

## Step 3 — Gather standards

Collect every coding standard that applies, from two sources:

- **User-level**: instruction and rule files your harness already loaded into this session (custom instructions, `*.instructions.md`, memory files, rules), wherever they live. Keep those whose scope (e.g. `applyTo` globs) matches a changed file.
- **Repository-level**: fetched remotely from the PR's base branch — the reviewed repo is usually not the local workspace. Probe each of: `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.github/instructions/**`, `.cursor/rules/**`, `.cursorrules`, `CONTRIBUTING.md`, plus any file those documents point to as a standard. A missing path is skipped.

Done when: every candidate path has been probed and you can list the standards you will apply.

## Step 4 — Analyze

Read every changed file in full at the head commit, not only its hunks. Judge each change against the rubric below and against every standard from Step 3. Anchor each finding to one line (or a line range) present in the diff: right side for added/changed code, left side for removed code.

### Rubric

- 🔴 **CRITICAL — Security** (blocks merge): exposed secrets, credentials or PII; injection, XSS, CSRF and other OWASP Top 10 classes; missing authentication or authorization; weak or deprecated crypto; unvalidated input.
- 🔴 **CRITICAL — Correctness** (blocks merge): logic and off-by-one errors; races and concurrency misuse; data corruption; unversioned breaking changes to public APIs.
- 🟡 **IMPORTANT — Quality** (needs discussion): SOLID violations, significant duplication; missing tests for new or critical paths; performance traps (N+1 queries, leaks, needless allocation); deviation from established architecture. Judge each one **merge-blocking** or not, with a one-line reason: merge-blocking when shipping it as-is would cause real harm (an untested critical path, a leak under normal load), not when it is a follow-up worth doing.
- 🟢 **SUGGESTION — Style** (non-blocking): naming, magic values, deep nesting, inconsistency with the surrounding codebase, minor deviations from a standard.
- ✅ **Positive** observation tied to a specific line (optional).

Also check the PR for **incomplete implementation**: work the description promises that the diff lacks, or stubs and TODOs left in new code paths. Record each as a finding.

Done when: every changed file and every standard is accounted for, each either yielding findings or noted as clean, and every 🟡 finding carries a merge-blocking judgement.

### Verdict

Three verdicts exist: **Approve**, **Comment** (comments only, no vote), **Request changes**. The agent suggests one of the first two; Request changes is applied only when the user explicitly asks for it.

- Suggest **Comment** when the draft holds any 🔴 finding, any merge-blocking 🟡 finding, or an incomplete implementation.
- Otherwise suggest **Approve**; the inline comments then go out as optional suggestions.
- On a **self-authored** PR (author is the account the tier is authenticated as), GitHub accepts only Comment: offer Comment and say why.

## Step 5 — Present the draft

Show the user the full draft; post nothing yet.

1. A numbered table: `#`, severity, `file:line`, short title, **Blocks** (yes for 🔴, incomplete implementation, and merge-blocking 🟡; no otherwise).
2. Each inline comment body in full, under its number, in this format:

   ````
   <emoji> **<Priority> — <Category>: <Short title>**

   <What is wrong and why it matters.>

   **Suggested fix:**
   ```<language>
   <corrected snippet>
   ```

   *Reviewed by <signer>*
   ````

3. The summary comment in full: a verdict line (on Approve: "Approved — inline comments are non-blocking suggestions"; on Comment: "Not ready to merge yet — see blocking findings"; on Request changes: "Changes requested — see blocking findings"); 1–3 sentences on what the PR does and whether it is sound; a **What's good** bullet list; the finding count (e.g. "1 critical, 2 important, 1 suggestion — see inline comments"); ending with `*Reviewed by <signer>*`.
4. The suggested verdict with a one-line rationale naming the blocking findings by number, if any.

Then ask the user to approve, drop findings by number, edit text, line, or severity, or override the verdict.

Done when: every finding, the summary, and the suggested verdict are on screen in full, and the user has been asked to decide.

## Step 6 — Confirm

Apply each change the user requests and re-show the affected comments. When findings are dropped or edited, re-derive the suggested verdict and the summary's verdict line from the remaining set, unless the user has already overridden the verdict. A user override stands as given. Repeat until the user explicitly approves posting.

Done when: the user has explicitly approved both the current approved set and the verdict.

## Step 7 — Post

Post the approved set through the chosen tier, exactly as approved, following the posting recipe in PLATFORMS.md: one inline comment per finding, the summary comment, and the confirmed verdict. If a comment fails to post (e.g. its line is outside the diff), keep posting the rest and record the failure.

Done when: every comment in the approved set was posted or recorded as failed, and the verdict was submitted or recorded as failed.

## Step 8 — Report

Reply with the PR link, the verdict submitted, the number of comments posted (inline + summary), any failures with their text (or the vote command) so the user can finish by hand, and a one-line summary of the most important finding.
