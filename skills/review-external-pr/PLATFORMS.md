# Platform tooling

Per-platform recipes for [SKILL.md](SKILL.md). Read only the section for the PR's platform. Within it, use the first **tier** whose check passes: CLI → MCP → guidance.

MCP tool names carry a harness-specific prefix (`mcp_github_…`, `github-…`, `mcp__github__…`); match on the suffix given here.

## Verdict mapping

| Verdict | GitHub review `event` | Azure DevOps vote |
|---|---|---|
| Approve | `APPROVE` | `approve-with-suggestions` if any inline comment was posted, else `approve` |
| Comment | `COMMENT` | no vote; `reset` if your account already voted |
| Request changes | `REQUEST_CHANGES` | `wait-for-author` |

On GitHub a `COMMENT` review leaves your earlier `APPROVE` or `REQUEST_CHANGES` in effect; a later `APPROVE` or `REQUEST_CHANGES` replaces it.

**Thread status** on re-review: Resolved and Accepted dismissal → GitHub *resolve* / ADO `fixed` and `wontFix` respectively; reopen → GitHub *unresolve* / ADO `active`.

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

**History** (re-review):
- Reviews and threads in one call:
  ```sh
  gh api graphql -F owner=<owner> -F repo=<repo> -F n=<n> -f query='query($owner:String!,$repo:String!,$n:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$n){
    reviews(last:100){nodes{author{login} state commit{oid} submittedAt}}
    reviewThreads(first:100){nodes{id isResolved isOutdated path line originalLine
      comments(first:100){nodes{databaseId author{login} body createdAt}}}}}}}'
  ```
  Previous threads: first comment's `author.login` is you. Baseline: `commit.oid` of your latest review by `submittedAt`. Latest verdict: that review's `state`.
- Conversation comments: `gh api repos/<owner>/<repo>/issues/<n>/comments --paginate`
- Delta check: `gh api repos/<owner>/<repo>/compare/<baseline>...<head> --jq '{status, merges: [.commits[] | select(.parents | length > 1)] | length}'`. Use the delta only when `status` is `ahead` and `merges` is 0; a 404 means the baseline is gone. Delta: the same URL with `-H "Accept: application/vnd.github.diff"`.

**Thread replies** (re-review):
- Reply: `gh api repos/<owner>/<repo>/pulls/<n>/comments/<databaseId>/replies --method POST --input reply.json` with `{"body": "<reply>"}`; `<databaseId>` is the thread's first comment.
- Resolve / reopen: `gh api graphql -F id=<thread id> -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}'`; `unresolveReviewThread` to reopen.

### Tier 2 — GitHub MCP server

**Check**: a `pull_request_read` tool exists and returns the PR (`method: get`).

**Read**: `pull_request_read` with `get`, `get_diff`, `get_files`; `get_file_contents` with `ref` = base branch for standards; `get_me` for the self-authored check.

**Post**: `pull_request_review_write` with `method: create` and `commitID` = head SHA (omit `event`, which opens a pending review) → `add_comment_to_pending_review` per finding (`path`, `line`, `side`, `startLine`/`startSide` for ranges, `subjectType: LINE`) → `pull_request_review_write` with `method: submit_pending`, `event` = the mapped verdict, `body` = summary.

**History** (re-review): `pull_request_read` with `get_reviews` (author, `commit_id`, state → baseline and latest verdict), `get_review_comments` (threads with resolution state, node IDs, and comment IDs), `get_comments` (conversation). Delta: `get_commits`; when the baseline is in the list and no later commit has two parents, fetch each later commit with `get_commit` and combine their diffs; otherwise use the full diff.

**Thread replies** (re-review): `add_reply_to_pull_request_comment` with `commentId` = the thread's first comment's numeric ID; `pull_request_review_write` with `method: resolve_thread` or `unresolve_thread` and `threadId` = the thread's node ID (`PRRT_…`).

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

Then cast the vote from the mapping (for Comment, only when resetting an earlier vote): `az repos pr set-vote --id <n> --vote <value>`. A branch policy can forbid authors from voting on their own PR; record that as a failed verdict.

**History** (re-review):
- Authenticated account: `az account show --query user.name -o tsv`, matched against `author.uniqueName`. Latest verdict: your entry in `reviewers[]` from `az repos pr show` (`vote`: 10 approve, 5 approve with suggestions, -5 wait for author, -10 reject).
- Threads: `az devops invoke --area git --resource pullRequestThreads --route-parameters project=<project> repositoryId=<repoId> pullRequestId=<n> --api-version 7.1` → `id`, `status`, `threadContext`, `comments[]` (`author.uniqueName`, `content`, `publishedDate`; skip `commentType: system`). Previous threads: first comment is yours.
- Iterations: same call with `--resource pullRequestIterations` → `id`, `sourceRefCommit.commitId`, `createdDate`. Baseline: the commit of the latest iteration created before your latest comment. A vote-only earlier round leaves no timestamp: use the full diff.
- Delta, in the temp clone: use the delta only when `git merge-base --is-ancestor <baseline> <head>` succeeds and `git rev-list --merges <baseline>..<head>` is empty; then `git diff <baseline> <head>`.

**Thread replies** (re-review):
- Reply: `az devops invoke --area git --resource pullRequestThreadComments --route-parameters project=<project> repositoryId=<repoId> pullRequestId=<n> threadId=<id> --http-method POST --in-file reply.json --api-version 7.1` with `{"parentCommentId": 1, "commentType": 1, "content": "<reply>"}`.
- Status: `--resource pullRequestThreads --route-parameters … threadId=<id> --http-method PATCH --in-file status.json` with `{"status": "<fixed | wontFix | active>"}`.

### Tier 2 — Azure DevOps MCP server

**Check**: a `repo_get_pull_request_by_id` / `repo_pull_request` tool exists and returns the PR.

**Read**: the pull-request tool for metadata; `repo_get_pull_request_changes` (or the equivalent changes call) for the diff; `repo_get_file_content` / `repo_file` with the target branch for standards.

**Post**: `repo_pull_request_thread_write` with `action: create` per finding (`filePath`, `rightFileStartLine`, `rightFileEndLine` + `rightFileEndOffset`); then one thread without file context for the summary. Cast the vote with `repo_pull_request_write`, `action: vote`, `vote` = `Approved` / `ApprovedWithSuggestions` / `NoVote` (reset) / `WaitingForAuthor`. If the vote fails, record it and give the user the `az repos pr set-vote` command or the web UI's Approve menu.

**History** (re-review): `repo_pull_request_thread` with `action: list` and `fullResponse: true` (threads, status, comments with authors); `repo_pull_request` with `action: get` for your vote in the reviewers. This tier has no iteration lookup: reuse a baseline from this session, else use the full diff. Without an identity lookup, previous threads are those whose first comment carries your signer line.

**Thread replies** (re-review): `repo_pull_request_thread_write` with `action: reply` (`threadId`, `content`), and `action: update_status` with `status` = `Fixed` / `WontFix` / `Active`.

### Tier 3 — guidance

- Install the Azure CLI (https://aka.ms/installazurecli), then `az extension add --name azure-devops` and `az login` with an account in `<org>`. For a tenant-specific org: `az login --tenant <tenantId>`.
- Or configure the Azure DevOps MCP server (https://github.com/microsoft/azure-devops-mcp) in the harness's MCP settings for `<org>`.
