---
name: high-level-design
description: Compile a high-level design document (HLDD) from a design's existing artifacts (spec, decision tickets, ADRs, glossary, measurements), whether the design is finished or still in progress.
argument-hint: "Feature folder or design to document"
disable-model-invocation: true
metadata:
  internal: true
---

# High-level design

An HLDD is a **view** over a design. It is one document where stakeholders see the whole system at a glance: requirements, structure, flows, deployment and risks. The decisions themselves live in their own artifacts (tickets, ADRs, spec). The view gathers them, arranges them and links back. When the view and a source disagree, the source wins, and the HLDD's header says so.

## 1. Gather

Read every design artifact:

- the spec or goals document;
- the decision map and **every** ticket, resolved and open;
- the ADRs;
- the glossary;
- measurement and baseline files;
- handoff notes;
- uncommitted edits on the branch (`git status`, `git diff`).

Give each design element a **maturity**:

| Tag | Meaning |
| --- | ------- |
| ✅ Decided | Resolved in a ticket or an accepted ADR. |
| 🟡 Working | The current hypothesis; an open ticket owns it. |
| ❓ Open | Not designed yet. |

When artifacts conflict, the newest decision wins: amendments beat originals, resolved tickets beat handoff notes. Record which ADRs a later decision supersedes.

Done when every design element has a maturity and a named owning artifact.

## 2. Draft

Write `high-level-design.md` in the feature folder, unless the repo's conventions name another place. If an HLDD already exists, update it in place and add a row to its Revisions section.

Every section follows these rules:

- Put the maturity legend at the top. Tag each design element and link its owning artifact.
- **Gist and link.** The detail stays in its source; restate only what a stakeholder needs to follow the section.
- Use the project's glossary terms.
- Take numbers from measurement artifacts, with their window and source. A target with no measurement reads "TBD", with the ticket that owns it.
- Mark anything you **infer** beyond the sources, and carry it to the report.
- **Diagrams carry maturity too.** Every box, arrow and participant that depends on an open item shows ❓ and its ticket (a dashed edge, a labelled node or a spanning note). A diagram must stay true under every option the open ticket still considers. Placement, ownership and who-writes-what are where an unmade decision most easily slips in.

| # | Section | Contents | Diagram |
| - | ------- | -------- | ------- |
| 1 | Introduction | Purpose, scope (in and out), objectives mapped to the problems they solve, and today's system in one paragraph. | — |
| 2 | Functional requirements | Table: ID, requirement, source and maturity. | — |
| 3 | Non-functional requirements | Table: ID, quality attribute, requirement, measure or target next to its baseline. | — |
| 4 | Architectural overview | Principles, logical layers and how they relate. | C4 context; target shape |
| 5 | System components | Per component: responsibility, inputs and outputs, maturity, open points. Then the components being retired or superseded. | C4 container |
| 6 | Data flow and processing | End-to-end path of one unit of work, its protocols and its lifecycle. If the design has invariants, add an invariant-to-mechanism matrix. | Sequence; state |
| 7 | User interface | Key screens and flows, or "Not applicable" in one line. | Wireframes, if any |
| 8 | External interfaces | Table: interface, direction, protocol and format, contract, maturity. Then versioning and limits. | — |
| 9 | Deployment and environment | Environments, hosting, scaling, identity and network, data residency. | Deployment |
| 10 | Cross-cutting concerns | One subsection per quality the NFRs name: performance and capacity (with a baseline table), security, observability, cost. | — |
| 11 | Error handling | Failure catalogue: failure, detection, handling, maturity. | — |
| 12 | Risks and mitigations | Risk, impact, mitigation, owning ticket. | — |
| 13 | Validation, cutover and rollback | Only when the design replaces a running system. | — |
| 14 | Assumptions and constraints | Assumptions the design rests on, and platform or scope constraints. | — |
| 15 | Glossary and references | Key terms with a pointer to the canonical glossary; source artifacts; related work. | — |
| 16 | Revisions | Date and change. | — |

Done when:

- every section is present, or marked not applicable in one line;
- every requirement and invariant traces to a mechanism or to an open item;
- every open ticket in the sources appears somewhere in the document;
- text and diagrams agree: no diagram shows as settled what a principle or table marks ❓, and the reverse.

## 3. Validate

- **Links:** every relative link resolves from the document's folder.
- **Diagrams:** extract each Mermaid block to its own `.mmd` file and render it with `npx -y -p @mermaid-js/mermaid-cli mmdc -i <block>.mmd -o <block>.svg`. Common parse traps:
  - an id that is a keyword (`loop`, `end`, `alt`, `opt`, `note`) used as a participant or node: rename it (for example `LJ`);
  - a `;` inside sequence message text, which ends the statement: use a comma.

Delete the scratch files when you finish.

Done when no link is broken and every block renders.

## 4. Report

Tell the user:

- the document's path;
- its structure, briefly;
- every inference you added beyond the sources, so they can confirm or reject it;
- what you left for them, such as committing and linking the HLDD from the map or spec.
