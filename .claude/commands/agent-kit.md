---
name: agent-kit
description: >-
  Capture, run a UI flow, inspect nodes, HTTP-fetch, or PNG-diff a Godot 4
  project with AgentKit. Use when the user wants screenshots or clicks instead
  of godot -s /tmp.
---

Load skill `godot-agent-kit`. If `addons/agent_kit/` is missing next to `project.godot`, install it from this repo and ask to enable plugin **AgentKit**:

```bash
./install.sh --addon /ABS/GODOT_ROOT
```

**Isolation:** anything you create stays in `res://agent/` (flows, harness, fixtures, out). Do not edit business rules or InputMap. Do not wait for user OK — check those limits yourself (`evaluate.md`).

**Play:** play `res://debug/…` when the slice names it; otherwise the shipping scene. If the situation needs a debug scene and none was named, return only `NEED_SETUP`. Do not build that `.tscn` and do not `call()` it into place. Actions are InputMap `press` (`InputEventAction`). A raw keycode is a product bug. Skill `godot-playtest` → `plan.md`.

**Class cache:** `Could not find type "X"` when `X` is a `class_name` in a `.gd` is a stale `.godot/global_script_class_cache.cfg`. Run `godot --headless --path PROJECT --import --quit` once and rerun the flow. Do not edit the cache file. If the same error remains, return `CACHE_STALE` to the caller and stop.

Do not use `godot -s /tmp/*.gd`. Use:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT capture --out=res://agent/out/a.png --wait=1.1 --fail-on-error
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=boot_smoke.json --fail-on-error
```

Set `GODOT=` if the binary is not found. Capture/flow **without** `--headless`. JSON, harnesses, fixture scenes and PNG dumps in `res://agent/` of the game — nowhere else. Report `AGENT_OK` / `AGENT_FAIL` and PNG paths. Turn-based UI: `try_click` + `repeat`. `git diff --name-only` must stay under `agent/`.

Optional cable editor: `experimental/agent-flow-editor/` (`pnpm install` && `pnpm dev`). Same JSON as `--agent=flow`.

A playtest does not wait for user OK. The agent only writes under `res://agent/` and does not change business rules. This is not an MCP.
