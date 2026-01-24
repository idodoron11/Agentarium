---
name: daily-standup
description: >
  Generates a daily standup summary for the daily meeting by aggregating your recent work across Azure DevOps work items and both Azure DevOps and GitHub repositories. Use this skill when you want to summarize what you worked on yesterday (or last working day), what issues block you, and your progress on work items. Handles Sunday-Thursday work week, and focuses on detailed work item changes and code activity.
license: See LICENSE in project root
---

# Daily Standup Summary Skill

## Purpose
Generate a concise, actionable summary of your work for the daily meeting, focusing on:
- What you worked on yesterday (or last working day)
- What issues or blockers you encountered
- Progress on Azure DevOps work items
- Code activity in GitHub and Azure DevOps repos

## When to Use This Skill
Use when you need to prepare a daily standup update, especially for teams using Azure DevOps for work items and a mix of Azure DevOps and GitHub for code.

## Workflow
1. **Determine the relevant day:**
   - If today is Sunday, use Thursday as the previous working day.
   - Otherwise, use the previous calendar day.
2. **Query Azure DevOps work items** for changes since the relevant day, focusing on:
   - A PBI was broken down to tasks
   - Work item status changes
   - Comments added
   - Changes in `Original Estimate`, `Remaining`, `Completed Work`, `Time Spent`
   - New pull request or commit linked to the work item
   - New ticket or request linked to a task
3. **Query code activity** in both Azure DevOps and GitHub repos for:
   - Commits authored
   - Pull requests created, merged, or reviewed
   - PRs or commits linked to work items
4. **Format the summary** as a numbered or bullet list, with each item referencing a specific work item and explaining its status or progress. Include links to work items and PRs where possible.
5. **Highlight blockers** or issues that require attention.


## Output Format
The summary should be formatted as a numbered or bullet list. Each item should:
- Reference a specific work item (with link if available)
- Summarize the actual work done, focusing on the content of comments left on the work item to provide context, details, and next steps
- Explain the status or progress in a way that is meaningful for a daily standup (not just status changes, but what was accomplished, what decisions were made, what blockers exist, and what the next steps are)
- Group related changes under the same work item
- Clearly indicate blockers

If there is not enough information in the work item comments or activity history to provide a clear summary, actively ask the user for clarifications (e.g., "I see you moved ADO#1234 to 'In Progress' but there are no comments—can you describe what you worked on?").

Example:

```
1. [ADO#1234: Implement login page](https://dev.azure.com/org/project/_workitems/edit/1234)
   - Yesterday I implemented the login form UI and connected it to the backend API. Waiting for QA feedback on edge cases. (Status: In Progress)
2. [ADO#1250: Refactor API endpoints](https://dev.azure.com/org/project/_workitems/edit/1250)
   - Broke down the PBI into 3 tasks and discussed the approach with the backend team. Blocked until the new API credentials are provisioned. (Comment: "Waiting for review from backend team.")
3. [ADO#1300: Update documentation](https://dev.azure.com/org/project/_workitems/edit/1300)
   - Added new sections to the API docs and clarified usage examples. Linked to new ticket for follow-up improvements. (Comment: "Added usage examples for new endpoints.")
```

## Boundaries
- Does not summarize work outside Azure DevOps and GitHub
- Does not include personal notes unless added as work item comments
- Does not generate future plans, only summarizes recent activity

## Example Use Cases
- "What did I work on yesterday?"
- "What should I say in the daily meeting?"
- "Summarize my progress on Azure DevOps work items for the last working day."
- "List blockers and status changes for my assigned work items."
