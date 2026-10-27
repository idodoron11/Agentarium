# Distribution

How Agentarium's skills are packaged so that anyone can install them into whichever coding agent they use.

## Language

**Skill**:
A self-contained folder with a `SKILL.md` that a coding agent loads on demand.
_Avoid_: Plugin, extension, command

**Published skill**:
A skill that Agentarium ships to anyone through its install channels.
_Avoid_: Public skill, shipped skill, general skill

**Unpublished skill**:
A skill kept in the repo but not shipped by default, because it is personal or still a draft.
_Avoid_: Personal skill, draft skill, private skill, internal skill

**Coding agent**:
An AI coding product that loads skills, such as Claude Code, GitHub Copilot, Codex, or Cursor.
_Avoid_: Agent (alone), harness, assistant, tool

**Custom agent**:
A VS Code `*.agent.md` persona file; not a coding agent and not distributed with skills.
_Avoid_: Agent (alone)

**Install channel**:
A mechanism through which a user installs skills into a coding agent.
_Avoid_: Installer, distribution method

**Install scope**:
Where an installed skill applies: globally for the user, or to one project.
_Avoid_: Install level, location

**Release**:
A numbered version of the whole repo, cut on every push to `main`.
_Avoid_: Skill version, build

**Portable**:
A property of a skill whose instructions work unchanged in every supported coding agent.
_Avoid_: Cross-platform, agent-agnostic
