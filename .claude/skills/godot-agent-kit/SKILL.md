---
name: godot-agent-kit
description: >-
  Drives a Godot 4 project with the AgentKit CLI: viewport capture,
  click/type/press flows, node inspect, HTTP fetch, PNG diff. Use when
  capturing the game, writing res://agent/ flows or harnesses, or when
  tempted to add playtest helpers or test scenes outside res://agent/.
  Not an MCP.
---

# AgentKit

Addon `addons/agent_kit/` in the Godot project. Zero gameplay. The agent talks to Godot via CLI; `AGENT_OK` / `AGENT_FAIL` are the contract. **Everything** the agent creates for AgentKit lives in **`res://agent/`** — flows, harness scripts, fixture scenes, dumps. Not in the addon. Not in `src/` / `scenes/` / `tests/`.

## When to use

- Capture or run a UI flow (not a made-up PNG).
- Before/after a shader or layout: `capture` + `diff`.
- Download a file into `res://`: `fetch`.
- Understand a scene: `inspect --unique`.
- About to write `godot -s /tmp/*.gd` → stop, use AgentKit.

A human-style playtest does **not** wait for user OK. The playtester validates that it only writes under `res://agent/` and does not change business rules (`godot-playtest`).

## Install

```bash
./install.sh --addon /path/to/godot-project
```

Enable plugin **AgentKit**. Without `--agent=`, F5 is unchanged.

## Do not

```bash
godot --path game -s /tmp/capture.gd
```

Game `class_name` scripts compile **before** autoloads. Capture from the AgentKit autoload so it survives `change_scene`.

## Run

```bash
addons/agent_kit/cli.sh /ABS/PROJECT VERB [--flag=value ...]
# GODOT=/path/to/Godot if the binary is not on PATH
```

`cli.sh` adds `--headless` for `info` / `fetch` / `inspect` / `diff`. **Not** for `capture` / `flow` (pixels need a window).

| Verb | Use |
|------|-----|
| `flow` | `--flow=boot_smoke.json` `--out=res://agent/out` `--fail-on-error` |
| `capture` | `--out=res://agent/out/a.png` `--scene=res://...` `--wait=1.1` `--fail-on-error` |
| `diff` | `--a=` `--b=` `--out=` `--threshold=0.02` |
| `inspect` | `--unique` `--node=%CardView` `--scene=` |
| `fetch` | `--url=` `--out=` `--ua=` |
| `info` | viewport, main scene, version, InputMap |

Grep: `AGENT_OK`, `AGENT_FAIL`, `AGENT_SHOT=`, `AGENT_PRINT`, `AGENT_CLICK`, `AGENT_PRESS`, `AGENT_CALL`, `AGENT_STEP`, `AGENT_STEP_ERROR`, `AGENT_ERRORS`, `AGENT_SKIP`, `AGENT_REPEAT`, `AGENT_DIFF`, `AGENT_JSON`.

## Rules

1. Playtest files go under `res://agent/` only. Do **not** wait for permission. If the starting context is missing, return only `NEED_SETUP` to the caller and stop until they send `PLAYTEST_SETUP`. Template: [plan.md](../godot-playtest/plan.md). Cut: [evaluate.md](../godot-playtest/evaluate.md).
2. Flows in `res://agent/flows/*.json`. Steps: [flows.md](flows.md).
3. `press` only if `InputMap` already has that action. Missing action or a keycode (`KEY_A`, `65`) is a **product bug** — do not add the mapping. UI the player would use: `click` / `type`.
4. Harness only in `res://agent/harness/*.gd`, and only to prepare a scene the JSON cannot. No func that moves, shoots, or forces state. Never edit product `.gd` / `.tscn` / InputMap for the flow. Isolated worlds: `res://agent/fixtures/`.
5. Do not add spawn / force-state / count / pause helpers outside `agent/`.
6. Long / turn-based UI: `try_click` + `repeat`, not a hard `click` on a disabled button.
7. `git diff --name-only` after the playtest must stay under `agent/`.
8. `Could not find type` for a `class_name` that exists in a `.gd`: `--import` once, rerun. If it persists, return `CACHE_STALE` to the caller. Do not hand-edit the class cache.

Optional visual editor (not in `./install.sh`): `experimental/agent-flow-editor/` (`pnpm install` && `pnpm dev`).
