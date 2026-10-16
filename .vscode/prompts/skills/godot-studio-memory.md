---
name: godot-studio-memory
description: >-
  Notes that survive between Cursor chats for a Godot studio project:
  decisions, bugfixes, gotchas, user prefs, next step. Uses Engram MCP if
  those tools exist; otherwise .studio/MEMORY.md next to project.godot.
  Use at session start, when recalling past work, after a meaningful
  decision, or before ending a session.
---

# Memory across chats

PRD/RFC are product truth. This is the **studio notebook**: why X was chosen, a bug not to reopen, “next time start here”.

Do not install anything. If this chat has tools `mem_search` / `mem_save` / `mem_context` / `mem_session_summary` (**Engram**), use them. Otherwise `{folder_with_project.godot}/.studio/MEMORY.md`.

Do not save secrets. No dumps of diffs or tool calls.

## When

| Moment | Action |
|--------|--------|
| Session start, or “remember / what did we do” | Read context (MCP: `mem_context` then `mem_search`; else MEMORY.md) |
| Before re-deciding a pattern | Search; do not contradict a written decision silently |
| Bugfix, decision, gotcha, user preference | Write it **now** |
| Before “done” if there was product work | One paragraph: what shipped, what’s next, key files |

Note format (MCP `mem_save` or a heading in the file):

```text
**What**: one searchable sentence
**Why**: request / bug / feel
**Where**: path
**Learned**: gotcha (if any)
```

In the file, evolving decisions keep the same heading (`### architecture/mp-type`). Sessions: append at the end (`## 2026-09-15`).

If a note changes the product, also update PRD / RULES / VISUAL / RFC.

## Engram (optional)

A binary + MCP, not part of this repo. Only if the user wants it: `brew install gentleman-programming/tap/engram` and in the game `.cursor/mcp.json`:

```json
{ "mcpServers": { "engram": { "command": "engram", "args": ["mcp"] } } }
```

That is enough. No TUI, git-sync, or the rest of the ecosystem.
