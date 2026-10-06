# Rule: Plan Files

**Scope:** Universal — update the PROJECT CONFIG block when moving to a new project.

---

## PROJECT CONFIG
<!-- Update these two values when copying to a new project -->

```
PLAN_DIR = .cursor/plans
```

---

## Policy (universal — do not change)

Always write plan files to `<project-root>/<PLAN_DIR>/<descriptive-name>.md`.

Do NOT write plans to the default Claude plans folder (`C:\Users\<user>\.claude\plans\` on Windows or `~/.claude/plans/` on Mac/Linux).

## Naming convention

Use a short descriptive kebab-case name that describes the change — not a generated UUID:

- `fish-collected-state-refactor.md` ✅
- `crystalline-honking-aurora.md` ❌

## Why

- Plans saved inside the project are versioned with the code, visible in the IDE, and shareable.
- The default Claude plans folder is outside the repo — writing there first wastes tokens and requires a second copy.
- `.cursor/plans/` is a conventional Cursor location, so the intent is clear to anyone reading the repo.
