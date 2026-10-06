# Rule: Design Goes to a Plan File, Not Chat

**Scope:** Universal — no project config needed. Complements [plan-files.md](plan-files.md), [plan-diagrams.md](plan-diagrams.md).

---

## Policy

When presenting a design, **do not write the design body in the chat response** if either is true:

1. The design contains (or would contain) a **Mermaid diagram**, or
2. The design is **big enough** to warrant one — multiple sections, a before/after comparison, class-structure changes, a data/call-flow, or more than a short paragraph of prose.

Instead:

- Write the full design to a spec file in `<PLAN_DIR>` (`.cursor/plans/`) per [plan-files.md](plan-files.md), using Mermaid diagrams per [plan-diagrams.md](plan-diagrams.md) / [mermaid-diagrams.md](mermaid-diagrams.md).
- In chat, reply with **only**: a one-line pointer to the file, the single open design decision (if any) needing the user's call, and the next step. No section dumps, no inlined diagrams, no re-narration of what the file already holds.

### What may still go in chat

- A one-sentence summary + the clickable plan-file path.
- A **design fork** the user must resolve (`AskUserQuestion` or a short inline question) — the question and its options only, not the whole design around it.
- Build/verify evidence lines, status, and next-step prompt.

### What must NOT go in chat

- Mermaid diagrams (they belong in the plan file).
- Multi-section design write-ups, before/after structure tables, file-move maps, interface contracts — even if the user seems to want them fast. The file is the source of truth; chat points at it.

## Why

Long designs rendered in chat are transient, unversioned, and re-narrated on every follow-up — burning tokens and drifting from the file. A design worth a diagram is worth a versioned file in the repo. Keeping chat to "pointer + open question + next step" makes the plan file the single source of truth and keeps the conversation scannable.
