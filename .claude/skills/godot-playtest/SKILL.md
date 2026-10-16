---
name: godot-playtest
description: >-
  Launches the Godot 4 binary and exercises acceptance criteria like a
  player (run scene, click, screenshot, AgentKit flow). Use when a slice
  needs a playtest or studio-playtester is invoked. Does not wait for
  permission. Returns NEED_SETUP to the caller when the starting context
  is missing. On a stale class_name cache, imports once and retries; if
  it persists, returns CACHE_STALE to the caller. Never creates playtest
  files outside res://agent/. Never edits business rules.
---

# Playtest

Run the **game** and check this slice as a player would. Not unit tests.

Do not wait for permission to playtest. Validate limits yourself ([evaluate.md](evaluate.md)).

If the slice needs a starting context you cannot see in the product scene and the caller did not send `PLAYTEST_SETUP`, return only `NEED_SETUP` to whoever invoked you (agent or human) and stop. Template: [plan.md](plan.md). When they relaunch with `PLAYTEST_SETUP`, build the fixture from those initial conditions and continue.

## 0. Self-check

You may create flows, fixtures and harness files under `res://agent/` only. Do not edit business rules (`scenes/`, `src/`, resources, `project.godot`, InputMap). Put the tree in the report; do not stop for `PLAN_OK`. Template: [plan.md](plan.md).

Player actions are InputMap `press` or a real UI control (`click` / `type`). A missing action is a product bug — do not send keycodes and do not add the mapping. The harness does not move or force state.

## 1. What to exercise

**All** acceptance criteria of **this** slice (the user request; FEATURES/RFC only if the game already has them). Not a sample of 3–7. If it does not fit in ~15 steps, the slice was too big: cover it and list what was left out. Each step must **fail in view** if the bug remains.

If `addons/agent_kit/` exists: `inspect --unique` and `info` (InputMap) first. Play the shipping scene when the criterion already starts there. Otherwise play the `res://debug/…` scene named in the prompt, FEATURES, or RFC. If that scene is missing, return only `NEED_SETUP` and stop — do not author it and do not `call()` it into existence. Drive the action with an InputMap `press` (an `InputEventAction`, so `_unhandled_input` counts) or `click` / `type` on the player’s control. Do not teleport or set `velocity`. A raw keycode, or a script that ignores the mapped action, is a product bug. Nothing you create leaves `res://agent/`.

## 2. Launch

1. Binary: `cli.sh` finds Godot, or set `GODOT=`.
2. `--path` = folder with `project.godot`.
3. Prefer a **window** (`--resolution` from `project.godot`) for input and pixels. Headless only for parse/load.
4. Use `--fail-on-error` on capture/flow.

## 3. Capture

Prefer AgentKit:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT inspect --unique
addons/agent_kit/cli.sh /ABS/GODOT_ROOT capture --out=res://agent/out/playtest.png --wait=1.1 --fail-on-error
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=boot_smoke.json --out=res://agent/out --fail-on-error
```

Grep `AGENT_OK`, `AGENT_FAIL`, `AGENT_STEP`, `AGENT_STEP_ERROR`, `AGENT_ERRORS`, `ERROR:`, `SCRIPT ERROR:`, `WARNING:`. Turn-based UI: `try_click` + `repeat`. **Do not** `godot -s /tmp/capture.gd`.

`--fail-on-error` fails the run if the engine logged ERROR / SCRIPT ERROR even when clicks “worked”. Include that log in the report.

A `SCRIPT ERROR` of `Could not find type "X"` or `Could not resolve external class member`, when `X` is a `class_name` already in a project `.gd`, is a stale `.godot/global_script_class_cache.cfg`. Do not edit that file. Do not call it a product bug yet. Once:

```bash
"$GODOT" --headless --path /ABS/GODOT_ROOT --import --quit
```

Rerun the same flow. If the type error is gone, continue the slice and say you imported. If the same type error remains, return only `CACHE_STALE` ([plan.md](plan.md)) to whoever invoked you and stop. They import or fix the project. Do not import a second time.

If the addon is missing, temporary fallback: [capture.md](capture.md). Headless does not give pixels.

## 4. Report

- Command, scene, JSON if you ran a flow. Name the fixture vs main, InputMap actions, and whether hooks were reused.
- Each criterion / step: PASS / FAIL. If the criterion names something visible, open the PNG and say what it shows. A side effect (a number changed, a label flipped) does not pass when the shot shows a different thing (a stack of boxes instead of what was asked, actors piled instead of the layout). Do not file that as a look nit.
- Console: `AGENT_ERRORS` and `ERROR:` / `SCRIPT ERROR:` / `WARNING:`. A script error is FAIL after the cache retry. A type error that survived one `--import` is `CACHE_STALE` for the caller, not a failed shot.
- What you could not exercise (no display, missing save, …).
- Process FAIL if any new/edited path is outside `agent/`. Paste `git diff --name-only`.
- Do not rewrite systems. Do not judge look.
