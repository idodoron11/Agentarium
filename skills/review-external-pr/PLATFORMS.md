# Platform tooling

Per-platform recipes for [SKILL.md](SKILL.md). Read only the section for the PR's platform. Within it, use the first **tier** whose check passes: CLI → MCP → guidance.

MCP tool names carry a harness-specific prefix (`mcp_github_…`, `github-…`, `mcp__github__…`); match on the suffix given here.

## Verdict mapping

| Verdict | GitHub review `event` | Azure DevOps vote |
|---|---|---|
| Approve | `APPROVE` | `approve-with-suggestions` if any inline comment was posted, else `approve` |
| Comment | `COMMENT` | no vote |
| Request changes | `REQUEST_CHANGES` | `wait-for-author` |

## GitHub

### Tier 1 — `gh` CLI

**Check**: `gh auth status` succeeds and `gh pr view <url> --json number` returns the PR. A 404 on a repo you can open in the browser means the account lacks access (SSO not authorized, or wrong account) — misconfigured.

**Read**:
- Metadata: `gh pr view <url> --json title,body,author,baseRefName,headRefOid,files`
- Authenticated user (self-authored check): `gh api user --jq .login`, compared with `author.login`
- Diff: `gh pr diff <url>`
- File at a ref: `gh api "repos/<owner>/<repo>/contents/<path>?ref=<ref>" -H "Accept: application/vnd.github.raw"`
- Directory listing: `gh api "repos/<owner>/<repo>/contents/<dir>?ref=<ref>" --jq '.[].path'` (404 → path absent)

**Post** — one call creates the whole review with its inline comments and the verdict (`event` from the mapping above). Write the payload to a temp file and send it:

```json
{
  "commit_id": "<headRefOid>",
  "event": "<APPROVE | COMMENT | REQUEST_CHANGES>",
  "body": "<summary comment>",
  "comments": [
    { "path": "src/a.ts", "line": 42, "side": "RIGHT", "body": "<comment>" },
    { "path": "src/b.ts", "start_line": 10, "start_side": "RIGHT", "line": 14, "side": "RIGHT", "body": "<comment>" }
  ]
}
```

`gh api repos/<owner>/<repo>/pulls/<n>/reviews --method POST --input review.json`

A 422 means at least one comment is anchored outside the diff and the whole review is rejected: move each offending finding into the summary body under its file and line, record it as a failure, and resend. Delete the temp file afterwards.

### Tier 2 — GitHub MCP server

**Check**: a `pull_request_read` tool exists and returns the PR (`method: get`).

**Read**: `pull_request_read` with `get`, `get_diff`, `get_files`; `get_file_contents` with `ref` = base branch for standards; `get_me` for the self-authored check.

**Post**: `pull_request_review_write` with `method: create` and `commitID` = head SHA (omit `event`, which opens a pending review) → `add_comment_to_pending_review` per finding (`path`, `line`, `side`, `startLine`/`startSide` for ranges, `subjectType: LINE`) → `pull_request_review_write` with `method: submit_pending`, `event` = the mapped verdict, `body` = summary.

### Tier 3 — guidance

- Install `gh` (https://cli.github.com), then `gh auth login`. For SSO-protected orgs: `gh auth refresh -h github.com -s repo` and authorize the token for the org.
- Or configure the GitHub MCP server (https://github.com/github/github-mcp-server) in the harness's MCP settings with a token that can read the repo and write PR reviews.

## Azure DevOps

Parse `<org>`, `<project>`, `<repo>`, `<n>` from the URL. Pass `--org https://dev.azure.com/<org> --detect false` on every `az` call so the local git remote is ignored.

### Tier 1 — `az` CLI with the `azure-devops` extension

**Check**: `az extension show --name azure-devops` succeeds, `az account show` succeeds, and `az repos pr show --id <n>` returns the PR. A 401/403 or "TF400813" means the signed-in account lacks access to that org — misconfigured.

**Read**:
- Metadata: `az repos pr show --id <n>` → `title`, `description`, `createdBy`, `targetRefName` (base), `lastMergeSourceCommit.commitId` (head), `lastMergeTargetCommit.commitId`, `repository.id`, `repository.remoteUrl`.
- Diff: `az repos` has no diff command. Clone into a temp directory with an AAD token and diff the two commits:
  ```sh
  TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
  git -c http.extraHeader="Authorization: Bearer $TOKEN" clone --filter=blob:none --no-checkout <remoteUrl> <tmpdir>
  git -C <tmpdir> -c http.extraHeader="Authorization: Bearer $TOKEN" fetch origin <head> <targetHead>
  git -C <tmpdir> diff <targetHead>...<head>
  ```
  The same clone serves file reads (`git -C <tmpdir> show <ref>:<path>`) for standards and full-file reads. Delete it afterwards.
- File at a ref without git: `az devops invoke --area git --resource items --route-parameters project=<project> repositoryId=<repoId> --query-parameters path=/<path> versionDescriptor.version=<branch> versionDescriptor.versionType=branch includeContent=true --api-version 7.1`

**Post** — one thread per finding, plus one thread without `threadContext` for the summary:

```json
{
  "status": "active",
  "comments": [ { "parentCommentId": 0, "commentType": 1, "content": "<comment>" } ],
  "threadContext": {
    "filePath": "/src/a.ts",
    "rightFileStart": { "line": 42, "offset": 1 },
    "rightFileEnd":   { "line": 42, "offset": 1 }
  }
}
```

Use `leftFileStart`/`leftFileEnd` instead for findings on removed lines.

`az devops invoke --area git --resource pullRequestThreads --route-parameters project=<project> repositoryId=<repoId> pullRequestId=<n> --http-method POST --in-file thread.json --api-version 7.1`

Then cast the vote from the mapping (skip for Comment): `az repos pr set-vote --id <n> --vote <value>`. A branch policy can forbid authors from voting on their own PR; record that as a failed verdict.

### Tier 2 — Azure DevOps MCP server

**Check**: a `repo_get_pull_request_by_id` / `repo_pull_request` tool exists and returns the PR.

**Read**: the pull-request tool for metadata; `repo_get_pull_request_changes` (or the equivalent changes call) for the diff; `repo_get_file_content` / `repo_file` with the target branch for standards.

**Post**: `repo_create_pull_request_thread` / `repo_pull_request_thread_write` per finding with `filePath`, `rightFileStartLine`, `rightFileEndLine`; then one thread without file context for the summary. Cast the vote with a reviewer-vote tool if one exists (e.g. `repo_update_pull_request_reviewers` / `repo_pull_request_write` with a vote); otherwise record the verdict as failed and give the user the `az repos pr set-vote` command or the web UI's Approve menu.

### Tier 3 — guidance

- Install the Azure CLI (https://aka.ms/installazurecli), then `az extension add --name azure-devops` and `az login` with an account in `<org>`. For a tenant-specific org: `az login --tenant <tenantId>`.
- Or configure the Azure DevOps MCP server (https://github.com/microsoft/azure-devops-mcp) in the harness's MCP settings for `<org>`.
