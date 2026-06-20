---
name: "Handoff"
description: "Compact the current conversation into a handoff document for another agent to pick up."
argument-hint: "What will the next session be used for?"
agent: "agent"
tools: [vscode, read, edit, search]
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it to the workspace root under `handoffs/YYYYMMDD-<topic>.md` (create the `handoffs/` directory if it does not exist; use today's date for YYYYMMDD and derive the topic slug from the user's argument or the conversation subject).

Include a "suggested skills" section in the document listing the skills the next agent should activate (e.g. `tdd`, `codebase-design`, `diagnosing-bugs`).

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed an argument, treat it as a description of what the next session will focus on and tailor the document accordingly.
