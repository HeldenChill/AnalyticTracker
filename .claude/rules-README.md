# .claude/rules

Rule files for this project. Each rule is a standalone `.md` file.
Copy to any other project's `.claude/rules/` and register in that project's `CLAUDE.md`.

---

## How rules are structured

Every rule file follows one of two patterns:

**Universal** — no project values needed, copy as-is:
```
# Rule: <Name>
Scope: Universal

[policy content only]
```

**Configurable** — has a `## PROJECT CONFIG` block at the top with a fenced code block of key=value pairs. When moving to a new project, **only edit that block** — the `## Policy` section below it is universal and should not change:
```
# Rule: <Name>
Scope: Project-specific — update the PROJECT CONFIG block when moving to a new project.

## PROJECT CONFIG
<!-- Update these values for each new project -->
` ` `
KEY = value
` ` `

## Policy (universal — do not change)
[rule content using KEY references]
```

---

## Rule index

| File | Scope | Config keys | Summary |
|------|-------|-------------|---------|
| [superpowers-plugin-setup.md](superpowers-plugin-setup.md) | Universal | — | Install and use Superpowers plugin skills for design, debugging, and planning workflows |
| [mermaid-diagrams.md](mermaid-diagrams.md) | Universal | — | Never use `()` `->` `=>` `==` in Mermaid labels |
| [plan-diagrams.md](plan-diagrams.md) | Universal | — | Prefer Mermaid diagrams over prose in plans; require before/after flow diagrams |
| [doc-diagrams.md](doc-diagrams.md) | Universal | — | Prefer Mermaid diagrams over prose in docs (`docs/`) |
| [plan-files.md](plan-files.md) | Universal | `PLAN_DIR` | Write plans to `.cursor/plans/`, not the default Claude folder |
| [debug-bug-workflow.md](debug-bug-workflow.md) | Universal | — | `/debug-bug` loop: agents do code, escalate design forks to user |
| [bug-lifecycle-tracking.md](bug-lifecycle-tracking.md) | Project | `BUG_LEDGER`, `BUG_ID_PREFIX` | Evidence-gated bug IDs, lifecycle states, verification and reporting contract |
| [bug-audit-workflow.md](bug-audit-workflow.md) | Universal | — | Bounded existing-flow audits, model roles, evidence and ledger handoff |
| [memory-write-rules.md](memory-write-rules.md) | Project | `CURSOR_MEMORY_DIR`, `CURSOR_MEMORY_PREFIX`, `CURSOR_MEMORY_INDEX`, `CLAUDE_MEMORY_DIR` | Two-tier memory pattern |
| [model-routing.md](model-routing.md) | Universal | — | Per-task model tier selection with escalation guardrails |
| [skip-subagent-driven-development.md](skip-subagent-driven-development.md) | Universal | — | Do NOT use `superpowers:subagent-driven-development`; dispatch agents directly; gate replaces reviewers |

---

## Adding a new rule

1. Create `.claude/rules/<rule-name>.md` following one of the two patterns above.
2. Add one row to the table in this README and in the `## Rules` table in `CLAUDE.md`.
3. If project-specific values are needed, put them all in a `## PROJECT CONFIG` fenced block at the top.

## Moving rules to a new project

1. Copy the desired rule files.
2. For each file with a `## PROJECT CONFIG` block: update only that block with the new project's values.
3. Register each file in the new project's `CLAUDE.md` rules table.
