#!/usr/bin/env node
// UserPromptSubmit hook: injects the project memory index into context on every
// user prompt so the main thread always SEES what .cursor/memory/mem-*.md files
// exist before deciding whether to read one. Enforces the memory-first workflow
// in .claude/rules/memory-first-workflow.md.
//
// Design notes:
// - The list is parsed live from .cursor/memory/mem-project-index.md
//   (its "Memory index" table) so this hook never drifts from the real index —
//   add a row there and it shows up here automatically. No duplicated list.
// - Output is tiny (the index table only, never memory bodies) to keep the
//   token cost negligible.
// - A hook cannot decide which memory is relevant or read it — that is
//   reasoning the model does. This hook only guarantees the menu is visible.

const fs = require("fs");
const path = require("path");

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const indexFile = path.join(
  root,
  ".cursor",
  "memory",
  "mem-project-index.md"
);

function readIndexRows() {
  let text;
  try {
    text = fs.readFileSync(indexFile, "utf8");
  } catch (e) {
    return null; // index file missing — stay silent
  }
  const lines = text.split(/\r?\n/);
  const rows = [];
  let inMemoryIndex = false;
  for (const line of lines) {
    // Enter only the "Memory index" section, leave at the next heading.
    if (/^##\s+Memory index/i.test(line)) {
      inMemoryIndex = true;
      continue;
    }
    if (inMemoryIndex && /^##\s/.test(line)) break;
    if (!inMemoryIndex) continue;
    // Match table data rows: | Topic | `mem-file.md` | — skip header/separator.
    const m = line.match(/^\|(.+)\|(.+)\|\s*$/);
    if (!m) continue;
    const topic = m[1].trim();
    const file = m[2].trim();
    if (/^-+$/.test(topic) || /^Topic$/i.test(topic)) continue; // header/sep
    rows.push(topic + " -> " + file);
  }
  return rows.length ? rows : null;
}

let raw = "";
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
  try {
    const all = readIndexRows();
    if (!all) return; // nothing to inject

    // ponytail: naive keyword overlap; swap for embeddings if matches get poor.
    // Full index (255+ rows) exceeds the hook output cap, so inject only rows
    // whose topic/file shares words with the prompt.
    let prompt = "";
    try {
      prompt = JSON.parse(raw).prompt || "";
    } catch (e) {}
    const STOP = new Set(["the", "and", "for", "you", "this", "that", "with", "what", "how", "can", "why", "now", "are", "not", "but", "have", "need", "want", "make", "check", "use"]);
    const words = [...new Set((prompt.toLowerCase().match(/[a-z0-9]{3,}/g) || []).filter((w) => !STOP.has(w)))];
    const rows = all
      .map((r) => {
        const t = r.toLowerCase();
        return { r, s: words.filter((w) => t.includes(w)).length };
      })
      .filter((x) => x.s > 0)
      .sort((a, b) => b.s - a.s)
      .slice(0, 15)
      .map((x) => (x.r.length > 220 ? x.r.slice(0, 217) + "..." : x.r));

    const body =
      "Full index (" + all.length + " rows): `## Memory index` in " +
      ".cursor/memory/mem-project-index.md. Rows below = " +
      (rows.length ? "keyword matches for this prompt." : "none matched; open the full index if the task may be covered.") +
      "\n" +
      "PROJECT MEMORY INDEX (memory-first workflow — " +
      ".claude/rules/memory-first-workflow.md):\n" +
      "Before answering or working on a task, FIRST check whether a memory " +
      "below covers it and read that .cursor/memory file. Only read source " +
      "files for gaps the memory does not cover, or to VERIFY before a code " +
      "edit / version-specific claim. Do not read source files to rebuild a " +
      "picture a memory already holds.\n" +
      rows.map((r) => "  - " + r).join("\n");

    const out = {
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: body,
      },
    };
    process.stdout.write(JSON.stringify(out));
  } catch (e) {
    // Never break prompt submission because the index hook failed.
  }
});
