# Pull Request Review

The back-and-forth between a reviewer and a PR author until the PR is ready to merge. The reviewer drafts and posts reviews; the author triages and responds to them.

## Review rounds

**Review round**:
One pass by the reviewer over a PR that ends with a verdict submitted on the platform.
_Avoid_: Iteration, pass

**Initial review**:
The first review round on a PR by the reviewer's account.
_Avoid_: First pass, fresh review

**Re-review**:
Any review round after the initial review, judging how the author responded to previous threads and what changed since.
_Avoid_: Follow-up review, re-evaluation, second review

**Baseline**:
The PR head commit at the time of the reviewer's latest review round.
_Avoid_: Last reviewed commit, base (which means the target branch)

**Delta**:
The changes between the baseline and the current PR head.
_Avoid_: Incremental diff, interdiff, limited diff

## Findings and threads

**Finding**:
One issue the reviewer raises, anchored to a line in the diff, with a severity.
_Avoid_: Issue, remark, note

**Blocking**:
A property of a finding that prevents an Approve verdict while it stands.
_Avoid_: Must-fix, required

**Previous thread**:
A review thread the reviewer's account opened in an earlier review round.
_Avoid_: Old comment, prior finding

**Thread outcome**:
The reviewer's judgement of how a previous thread was handled: Resolved, Partially resolved, Accepted dismissal, Contested dismissal, or Unaddressed.
_Avoid_: Status, resolution

**Dismissal**:
The author's reply to a thread explaining why no code change will be made.
_Avoid_: Rejection, won't-fix

## Decisions

**Verdict**:
The reviewer's vote on the PR in a review round: Approve, Comment, or Request changes.
_Avoid_: Decision, outcome, status

**Triage decision**:
The author's choice for an incoming thread: fix, explain, or dismiss.
_Avoid_: Verdict

**Signer**:
The name of the agent product that drafted a posted comment, written at its end.
_Avoid_: Author, bot name
