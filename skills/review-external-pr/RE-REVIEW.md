# Re-review

Re-review branch of [SKILL.md](SKILL.md): the author has responded to an earlier review round by your account. Each section below extends the SKILL.md step it names. Terms (baseline, delta, previous thread, thread outcome, dismissal) are defined in the repo's [GLOSSARY.md](../../GLOSSARY.md).

## Step 3 — Fetch history

Collect, through the chosen tier ([PLATFORMS.md](PLATFORMS.md), *History* recipes):

- **Previous threads**: every thread whose first comment is by your account, whatever its status (open, resolved, outdated). For each, record: thread id, `file:line`, the original comment, every reply after it, and its platform status. Take severity and **Blocks** from the posted header (`🟡 **IMPORTANT — Quality (blocking): …**`; 🔴 always blocks, 🟢 never does). When the header is absent (a comment you wrote by hand), infer both and mark them *(inferred)*.
- **Other reviewers' open threads** and the PR conversation comments: context for the author's changes.
- **Your latest verdict** on the PR, and the **round number**: your earlier review rounds + 1.
- **Baseline**: when this session ran and posted the previous round, reuse its head SHA. Otherwise use the platform-recorded baseline.
- **Delta**: the diff from baseline to the current head. Fall back to the **full diff** when the baseline is unknown, is not an ancestor of the head (rebase, force-push), or the range contains a merge commit (the base branch was merged in). Record the reason.

Done when: every previous thread carries severity, Blocks, replies and status; the baseline is a SHA or a recorded fallback reason; and you hold the delta (or full diff) for every file it touches.

## Step 5 — Analyze

**Judge every previous thread**: open, author-resolved, and outdated alike. Read the code at the thread's anchor in the head commit (for an outdated thread, locate the code by content), the author's replies, and the delta. Assign one **thread outcome**:

| Thread outcome | Meaning | Still blocks? | Action |
|---|---|---|---|
| **Resolved** | A code change fixes the finding. | no | reply, resolve |
| **Accepted dismissal** | No code change; the author's reason holds. | no | reply, resolve |
| **Partially resolved** | A change was made; part of the issue remains. | original Blocks | reply, keep open (reopen if closed) |
| **Contested dismissal** | No code change; the author's reason does not hold. | original Blocks | reply, keep open (reopen if closed) |
| **Unaddressed** | No code change, no reply. | original Blocks | reply, keep open (reopen if closed) |

A contested dismissal of a 🔴 finding blocks; flag it in the draft so the user can downgrade it.

**Find new findings** with the SKILL.md rubric, scoped to:
- lines in the **delta**, at every severity;
- 🔴 issues anywhere in the PR, tagged *outside delta*;
- an open 🔴 thread by another reviewer that you agree with and no previous thread covers: raise it as your own finding, crediting them.

Done when: every previous thread has a thread outcome with a one-line justification, and every file in the delta is accounted for as yielding findings or clean.

### Verdict

The **blocking set** is every previous thread that still blocks plus every new blocking finding. Apply the SKILL.md verdict rules to it, with one carry-over: when your latest verdict was **Request changes** and the blocking set is non-empty, suggest Request changes again. When your latest verdict was **Approve** on GitHub and the suggestion is now Comment, note in the draft that the earlier approval stays in effect unless the user overrides to Request changes.

## Step 6 — Present the draft

Replace the initial-review table with:

1. **Baseline**: the SHA, or `full diff — <reason>`.
2. **Previous threads**: `#`, `file:line`, original title, original severity and Blocks, thread outcome, **Blocks** now, action (reply + resolve / reply + keep open / reply + reopen).
3. Each reply body in full, under its number:

   ```
   **<Thread outcome>** — <what changed, why the dismissal holds, or what is still missing.>

   *Reviewed by <signer>*
   ```

4. **New findings**: the initial-review table with a **Scope** column (*delta* / *outside delta*), each comment body in full as in SKILL.md.
5. The summary comment, opening `Re-review (round <N>)`, then the verdict line, a count of thread outcomes (e.g. "4 resolved, 1 accepted dismissal, 1 still open"), the new-finding count, and `*Reviewed by <signer>*`.
6. The suggested verdict with its rationale, naming blocking items by number.

The user may drop or edit replies and change thread outcomes, as with findings.

## Step 8 — Post

First post every approved reply, then change thread status per its action (resolve, or reopen a thread the author closed). Then post the new findings, summary and verdict with the SKILL.md posting recipe. Record each failed reply or status change and keep going.
