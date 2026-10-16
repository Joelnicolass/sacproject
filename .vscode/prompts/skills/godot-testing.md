---
name: godot-testing
description: >-
  Test Godot 4 projects with GUT (GDScript) or GdUnit4 (C#). Use when writing
  unit tests, scene tests, CI headless runs, testing Resources, signals,
  RefCounted domain, or choosing a Godot test runner.
---

# Godot — tests

Do not invent a runner. Detect the one already there (GUT, GdUnit4, repo script). If there is none and the user asked for tests: **GUT** for GDScript, **GdUnit4** if the project is C#. Do not install a framework without saying so.

Architecture: [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## What to test

| Layer | How |
|------|------|
| Clean domain (`RefCounted`) | `MyRule.new()` in GUT/GdUnit. No scene, no autoloads. |
| Type Resource | Load `.tres` or construct the Resource; do not mutate the shared asset. |
| Node / component | Add as a child of the test; **autofree** (`add_child_autofree` in GUT). Test signals. |
| Feel / camera / juicy | Annotated playtest. A green unit test does not prove it feels right. |

No filler tests. Each test must **fail** if an acceptance criterion breaks.

## GUT (GDScript)

- Tests in `res://test/` (or the folder the project already uses).
- `extends GutTest`.
- Nodes: `add_child_autofree(scene.instantiate())` — do not leave orphan nodes.
- Signals: `watch_signals(node)` / `assert_signal_emitted`.
- Input: GUT helpers (`GutInputSender`) and **clear** them in teardown.
- Headless / CI: Godot binary `--headless -s addons/gut/gut_cmdln.gd` (match the real `project.godot`). Paste the output.

## GdUnit4 (C#)

- Use the project’s GdUnit4 runner. Scene runner / `simulate_action_*` per its API.
- Do not mix GUT and GdUnit4 in the same title without a reason.

## CI

Prefer `godot --headless` + the runner’s command line. “npm test” / TS typecheck do not apply.

## Anti-patterns

- Installing GUT “just in case” in a game the user did not want tests for.
- Testing the whole `.tscn` for a domain sum.
- Leaving nodes without free.
- Claiming feel coverage with an `assert_eq` on a shader float.
