# Review tooling

Review-only recipes that extend [PLATFORMS.md](PLATFORMS.md): posting a review, casting the verdict, and reading review history. Use the same platform section and tier you chose there.

## Verdict mapping

| Verdict | GitHub review `event` | Azure DevOps vote (CLI / MCP) |
|---|---|---|
| Approve | `APPROVE` | `approve-with-suggestions` / `ApprovedWithSuggestions` if any inline comment was posted, else `approve` / `Approved` |
| Comment | `COMMENT` | no vote; `reset` / `NoVote` if your account already voted |
| Request changes | `REQUEST_CHANGES` | `wait-for-author` / `WaitingForAuthor` |

On GitHub a `COMMENT` review leaves your earlier `APPROVE` or `REQUEST_CHANGES` in effect; a later `APPROVE` or `REQUEST_CHANGES` replaces it.

## Thread outcomes

On a re-review, apply each thread outcome's action through the PLATFORMS.md *Thread status* operations: **Resolved** → close as fixed; **Accepted dismissal** → close as won't fix; keep open on a thread the author closed → reopen.

## GitHub

### Tier 1 — `gh` CLI

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
- Reviews:
  ```sh
  gh api graphql -F owner=<owner> -F repo=<repo> -F n=<n> -f query='query($owner:String!,$repo:String!,$n:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$n){
    reviews(last:100){nodes{author{login} state commit{oid} submittedAt}}}}}'
  ```
  Baseline: `commit.oid` of your latest review by `submittedAt`. Latest verdict: that review's `state`.
- Delta check: `gh api repos/<owner>/<repo>/compare/<baseline>...<head> --jq '{status, merges: [.commits[] | select(.parents | length > 1)] | length}'`. Use the delta only when `status` is `ahead` and `merges` is 0; a 404 means the baseline is gone. Delta: the same URL with `-H "Accept: application/vnd.github.diff"`.

### Tier 2 — GitHub MCP server

**Post**: `pull_request_review_write` with `method: create` and `commitID` = head SHA (omit `event`, which opens a pending review) → `add_comment_to_pending_review` per finding (`path`, `line`, `side`, `startLine`/`startSide` for ranges, `subjectType: LINE`) → `pull_request_review_write` with `method: submit_pending`, `event` = the mapped verdict, `body` = summary.

**History** (re-review): `pull_request_read` with `get_reviews` (author, `commit_id`, state → baseline and latest verdict). Delta: `get_commits`; when the baseline is in the list and no later commit has two parents, fetch each later commit with `get_commit` and combine their diffs; otherwise use the full diff.

## Azure DevOps

### Tier 1 — `az` CLI with the `azure-devops` extension

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
- Latest verdict: your entry in `reviewers[]` from `az repos pr show` (`vote`: 10 approve, 5 approve with suggestions, -5 wait for author, -10 reject).
- Iterations: `az devops invoke --area git --resource pullRequestIterations --route-parameters project=<project> repositoryId=<repoId> pullRequestId=<n> --api-version 7.1` → `id`, `sourceRefCommit.commitId`, `createdDate`. Baseline: the commit of the latest iteration created before your latest comment. A vote-only earlier round leaves no timestamp: use the full diff.
- Delta, in the temp clone: use the delta only when `git merge-base --is-ancestor <baseline> <head>` succeeds and `git rev-list --merges <baseline>..<head>` is empty; then `git diff <baseline> <head>`.

### Tier 2 — Azure DevOps MCP server

**Post**: `repo_pull_request_thread_write` with `action: create` per finding (`filePath`, `rightFileStartLine`, `rightFileEndLine` + `rightFileEndOffset`); then one thread without file context for the summary. Cast the vote with `repo_pull_request_write`, `action: vote`, `vote` from the mapping. If the vote fails, record it and give the user the `az repos pr set-vote` command or the web UI's Approve menu. Servers before v2.9 use `repo_create_pull_request_thread` and `repo_vote_pull_request` instead.

**History** (re-review): `repo_pull_request` with `action: get` for your vote in the reviewers. This tier has no iteration lookup: reuse a baseline from this session, else use the full diff. Without an identity lookup, previous threads are those whose first comment carries your signer line.
