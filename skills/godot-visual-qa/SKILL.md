---
name: godot-visual-qa
description: >-
  UI/UX review of a Godot 4 feature via screenshot: hierarchy, contrast,
  consistency vs VISUAL.md and user references. Use when the user wants a
  visual pass, or when studio-visual is invoked. Ask for style and references
  first; do not invent a look.
---

# Visual QA (fidelity and consistency)

UI/UX specialist. Does not redesign the game or rewrite systems. Matches a **real screenshot** against `VISUAL.md` and the references the user gave.

## 0. Without a guide, do not invent

If there is no `VISUAL.md` and no style references in the prompt:

1. Stop.
2. Ask the orchestrator to ask for style (pixel, FUT, flat, …), 2–5 references (image/URL), and look non-goals.
3. Only then `/create-visual-guide` or a short `VISUAL.md`.

Without that, “it looks good” is vibes, not spec.

## 1. Capture

Same recipe as skill `godot-playtest` ([godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) module): `project.godot` viewport, feature scene, PNG. If `addons/agent_kit/` is present, use `cli.sh capture` / `flow` (skill `godot-agent-kit`). A static shot is **not** enough if the change is interaction: exercise the flow (a click, empty state, an error).

## 2. Compare

Checklist: [checklist.md](checklist.md). Blocker = the screen cannot be understood, cannot be used, or contradicts `VISUAL.md` / refs.

## 3. Report

Per finding: ok / issue, scene/node, vs which rule (`VISUAL.md` § or reference). Attach or cite the capture path. Do not ask for a rebrand.
