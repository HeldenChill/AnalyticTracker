# AnalyticTracker — Claude Code Context

Cross-platform analytics dashboard (Windows, Android, iOS, Web) that pulls game tracking data from Firebase/BigQuery daily and offers basic analysis to a small team. First data source: PetVsMonster (`D:\UnityProject\PetVsMonster`).

## Rules

All rules live in [.claude/rules/](.claude/rules/), one `.md` per rule; see [rules-README.md](.claude/rules-README.md). Register new rules below.

| Rule | What it governs |
|------|-----------------|
| [plan-files.md](.claude/rules/plan-files.md) | Plans go to `.cursor/plans/` |
| [design-to-plan-file.md](.claude/rules/design-to-plan-file.md) | Designs with diagrams go to a plan file; chat = pointer + open decision |
| [plan-diagrams.md](.claude/rules/plan-diagrams.md) | Mermaid over prose in plans; before/after flows |
| [doc-diagrams.md](.claude/rules/doc-diagrams.md) | Mermaid over prose in `docs/` |
| [mermaid-diagrams.md](.claude/rules/mermaid-diagrams.md) | Mermaid syntax safety |
| [memory-write-rules.md](.claude/rules/memory-write-rules.md) | `.cursor/memory/` (project) vs auto-memory (user/feedback) |
| [bug-lifecycle-tracking.md](.claude/rules/bug-lifecycle-tracking.md) | Bug ledger `mem-known-bugs-index.md` |
| [bug-audit-workflow.md](.claude/rules/bug-audit-workflow.md) | Scoped one-flow audits |
| [debug-bug-workflow.md](.claude/rules/debug-bug-workflow.md) | `/debug-bug` loop, design forks to user |
| [model-routing.md](.claude/rules/model-routing.md) | Model tier per agent spawn |
| [skip-subagent-driven-development.md](.claude/rules/skip-subagent-driven-development.md) | Don't use subagent-driven-development |
| [superpowers-plugin-setup.md](.claude/rules/superpowers-plugin-setup.md) | Skill usage rules |

## Quick orientation

- **Memory index:** `.cursor/memory/mem-project-index.md` (hook injects keyword-matched rows each prompt).
- **Default is inline** — no agent dispatch unless the user asks.
- **Stack:** NOT decided — research in `docs/research/stack-comparison.md`; intent + history in `.cursor/memory/mem-project-intent-and-origin.md`.
