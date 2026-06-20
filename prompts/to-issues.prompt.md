---
name: "To Issues"
description: "Break a plan, spec, or PRD into independently-grabbable Azure DevOps work items using tracer-bullet vertical slices."
argument-hint: 'Optional: area tag or iteration to assign to created work items (e.g. "Idu Client-Server\Projects\Content Analytics\DCE\CHAR TEAM", "Idu Client-Server\26Q2S4")'
agent: "story-expert"
---

# To Issues

Break a plan into independently-grabbable Azure DevOps work items using vertical slices (tracer bullets).

Create work items in the **`Idu Client-Server`** Azure DevOps project using the available Azure DevOps tools. If the parent work item cannot be determined from context, ask the user before creating anything.

If the user passed an Area Path or Iteration as an argument, apply it to every created work item. Otherwise inherit from the parent work item (or ask if creating orphans).

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a work item reference (ID or URL) as an argument, fetch it from Azure DevOps and read its full description and comments. Also fetch its parent and any child items for context.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Issue titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

<vertical-slice-rules>

- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Any prefactoring should be done first

</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?

Iterate until the user approves the breakdown.

### 5. Create the work items in Azure DevOps

For each approved slice, create a new **Task** (or **PBI** if the slice is large enough to warrant its own backlog item) in the `Idu Client-Server` project. Use the work item body template below.

Create work items in dependency order (blockers first) so you can reference real work item IDs in the "Blocked by" field. Link blocking relationships using Azure DevOps predecessor/successor links.

Apply estimation rules from story-expert:
- **Tasks**: set `Original Estimate` = `Remaining` = estimated hours (6 h = 1 day)
- **PBIs**: set `Effort` = estimated effort points (1 point = 1 day)
- When creating tasks under a PBI, verify that `sum of task hours = PBI effort × 6`

<work-item-template>
## Parent

ID and title of the parent Azure DevOps work item (if the source was an existing item, otherwise omit this section).

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

Avoid specific file paths or code snippets — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it here and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- ID and title of the blocking work item (if any)

Or "None - can start immediately" if no blockers.

</work-item-template>

Do NOT modify or close the parent work item.
