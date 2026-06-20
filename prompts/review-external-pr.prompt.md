---
description: "Review an external pull request from a GitHub or Azure DevOps URL. Posts findings as inline code comments on the PR — one comment per finding, each attached to the relevant line. Signs every comment with 'Reviewed by Copilot'."
name: "Review External PR"
argument-hint: "Paste the full PR URL (GitHub or Azure DevOps)"
agent: "agent"
tools: [vscode, read, agent, search, 'azure-devops/*', 'github/*']
---

# External PR Review

Review the pull request at the URL provided by the user.

## Step 1 — Fetch the PR

Determine the platform from the URL:
- **GitHub**: `github.com/owner/repo/pull/NUMBER` → use `mcp_github_mcp_se_pull_request_read` (methods: `get`, `get_diff`, `get_files`)
- **Azure DevOps**: `dev.azure.com/org/project/_git/repo/pullrequest/NUMBER` → use `mcp_azure_devops__repo_get_pull_request_changes`

Retrieve:
1. PR metadata (title, description, author, base branch, head commit SHA)
2. Full unified diff (`get_diff`)
3. List of changed files (`get_files`)

## Step 2 — Load Instruction Files

Load the following instruction files and apply their rules throughout the review:

**User-level instructions** (always apply, regardless of repository):
- Any `*.instructions.md` files found in `~/.copilot/instructions/` that match the files being reviewed (e.g., `clean-code.instructions.md`, `code-review.instructions.md`)

**Repository-level instructions** — always fetch remotely via API from the PR's repository (do NOT rely on local workspace files):

For **GitHub**, call `mcp_github_mcp_se_get_file_contents` with `ref` set to the PR's base branch (e.g. `main`):
1. Attempt to list `.github/instructions/` — fetch each `*.instructions.md` found there.
2. Attempt to fetch `.github/copilot-instructions.md`.
3. If a file is not found (404), skip it silently.

For **Azure DevOps**, call `mcp_azure_devops__repo_get_file_content` with the same paths against the target branch:
1. `.github/instructions/*.instructions.md` (list directory first, then fetch each file)
2. `.github/copilot-instructions.md`

Apply every instruction file that was successfully retrieved.

## Step 3 — Analyze the Diff

Read every changed file in full. For each change, evaluate:

### Security (🔴 CRITICAL — block merge)
- Exposed secrets, credentials, or PII in code or logs
- SQL injection, XSS, CSRF, or other OWASP Top 10 vulnerabilities
- Missing authentication or authorization checks
- Insecure cryptography or use of deprecated security APIs
- Unvalidated or unsanitized user inputs

### Correctness (🔴 CRITICAL — block merge)
- Logic errors or off-by-one mistakes
- Race conditions or threading issues (e.g., improper use of `Monitor.Pulse` vs `Monitor.PulseAll`)
- Data corruption risks
- Breaking changes to public APIs without versioning

### Code Quality (🟡 IMPORTANT — requires discussion)
- Violations of SOLID principles or major code duplication
- Missing tests for critical or new code paths
- Obvious performance issues (N+1 queries, memory leaks, unnecessary allocations)
- Architectural deviations from established patterns

### Style & Readability (🟢 SUGGESTION — non-blocking)
- Poor naming, magic numbers, or magic strings
- Overly complex or deeply nested logic
- Inconsistency with patterns established elsewhere in the same PR or codebase
- Minor deviations from the instruction-file conventions

## Step 4 — Post the Review

### Inline comments (one per finding)

For **every individual finding** — whether critical, important, or a suggestion — post a **separate inline comment** attached to the most relevant line in the diff.

**Workflow:**
1. Call `mcp_github_mcp_se_pull_request_review_write` with `method: "create"` and `commitID` set to the PR's head SHA to open a **pending review** (no `event` field — do NOT submit yet).
2. For each finding, call `mcp_github_mcp_se_add_comment_to_pending_review` with:
   - `path`: relative file path
   - `line`: the specific line number in the diff (RIGHT side for additions, LEFT for deletions)
   - `startLine` / `startSide` if the finding spans multiple lines
   - `side`: `RIGHT` for new code, `LEFT` for removed code
   - `subjectType`: `LINE`
   - `body`: the comment text (see format below)

**Comment body format:**
````
<priority-emoji> **<Priority> — <Category>: <Short title>**

<Explanation of the issue and why it matters.>

**Suggested fix:**
```<language>
// corrected code snippet
```

*Reviewed by Copilot*
````

Priority emoji mapping:
- 🔴 CRITICAL
- 🟡 IMPORTANT
- 🟢 SUGGESTION
- ✅ (for positive observations, if attached to a specific line)

### One general comment (summary + positives)

After all inline comments are queued, call `mcp_github_mcp_se_pull_request_review_write` with `method: "submit_pending"` and include in the `body`:

1. **Summary**: 1–3 sentences describing what the PR does and whether it is correct overall.
2. **What's good**: Bullet list of well-written aspects (clean design, correct use of patterns, good test coverage, helpful comments, etc.).
3. **Finding count**: e.g., "1 critical, 2 important, 1 suggestion — see inline comments."

End the body with:
```
*Reviewed by Copilot*
```

Use `event: "COMMENT"` (never APPROVE or REQUEST_CHANGES unless the user explicitly asks).

### Fallback for Azure DevOps

Azure DevOps does not support pending reviews. Use `mcp_azure_devops__repo_create_pull_request_thread` for each finding with `filePath`, `rightFileStartLine`, and `rightFileEndLine` populated. Post the general comment as a separate thread without file/line context.

## Step 5 — Report Back

After posting, reply to the user with:
- Link to the PR
- Total number of comments posted (inline + general)
- One-line summary of the most important finding
