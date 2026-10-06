# Rule: Mermaid Diagrams

**Scope:** Universal — no project config needed.

---

## Forbidden characters in label text

| Character | Why it breaks |
|-----------|--------------|
| `()` | Tokenized as function call |
| `->` | Conflicts with Mermaid arrow syntax |
| `=>` | Conflicts with thick-arrow syntax |
| `==` | Conflicts with thick-arrow syntax |
| `<>` | Conflicts with generics / HTML |

## Safe replacements

| Instead of | Use |
|------------|-----|
| `ChangeState(DIE)` | `ChangeState DIE` |
| `stamina == 0` | `stamina zero` or `stamina depleted` |
| `A -> B` | `A calls B` or `A then B` |
| `A => B` | `A then B` |

## Other syntax rules

- **Participant IDs** — no spaces without quoting. Use `FishFSM` not `Fish FSM`, or `participant "Fish FSM" as FSM`.
- **`stateDiagram-v2` transitions** — space before AND after the colon: `A --> B : label` not `A --> B: label`.
- **Keep labels short** — long labels with punctuation are the most common source of parse failures.

## Why

The Cursor / VS Code Mermaid extension uses a stricter parser than GitHub's renderer. Diagrams that render fine on GitHub can silently fail in Cursor with "No diagram type detected matching given configuration".
