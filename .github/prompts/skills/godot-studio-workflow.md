---
name: godot-studio-workflow
description: >-
  Orchestrates a Godot 4 game from idea to a simple scalable base: interviews
  the user (Clean vs standard, multiplayer type, 2D/3D, Aseprite/Blender MCP),
  runs product commands (PRD, features, rules, RFCs, visual guide), researches
  when needed, then delegates tech-lead / developer / reviewer (optional
  tester, playtester and visual). Use when starting a game, a Godot project,
  PRD, RFC, feature implementation, or when the user wants the studio
  workflow / orchestration.
---

# Godot studio — orchestrator

The **main agent in this chat** is the orchestrator. It talks to the user. It does not dump the whole product into one subagent.

Load: [spec-loop.md](spec-loop.md), [compact-rules.md](compact-rules.md), [file-tree.md](file-tree.md), [godot-layered-architecture](../godot-layered-architecture/SKILL.md), [godot-composition-first](../godot-composition-first/SKILL.md). Notes across chats: [godot-studio-memory](../godot-studio-memory/SKILL.md). Networking: [godot-mp-kit](../godot-mp-kit/SKILL.md) **only** if there is multiplayer. Captures / flows: skill `godot-agent-kit` from the [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) module (this kit’s `./install.sh` fetches it). Tests: [godot-testing](../godot-testing/SKILL.md) **only** if the user asks or RULES requires them. Juicy feel: [godot-juicy](../godot-juicy/SKILL.md) + `/add-juicy`. FSM: [godot-fsm](../godot-fsm/SKILL.md) + `/add-state-machine`. 2D platformer: [godot-platformer-2d](../godot-platformer-2d/SKILL.md) + `/add-platformer-2d`.

Goal: a Godot 4 game with a **small, clear base**. Priorities: clean layers, composition, editor/`@export`, reusable components.

Roles (`Task` `subagent_type` = their `name`):

| Role | Subagent | When |
|------|----------|------|
| Tech lead | `studio-tech-lead` | Plan one RFC/feature **before** code; **includes the file tree** |
| Developer | `studio-developer` | Implement **one** RFC or a bounded change |
| Reviewer | `studio-reviewer` | After implementation (one pass) |
| Tester | `studio-tester` | **Only** if the user asked for tests or RULES.md requires them |
| Playtester | `studio-playtester` (module [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)) | After review, on `res://debug/` or the player scene. Does not ask for a second OK |
| Visual | `studio-visual` | **Only** if the user wants a UI pass; requires `VISUAL.md` / refs |

Every `Task` includes the [compact-rules.md](compact-rules.md) block. Subagents **do not** see this chat.

If the `studio-playtester` subagent **does not exist** (the playtest module is not installed), do not invent it or simulate it with another role: offer a manual playtest (the user runs F5 and you walk the slice criteria as a checklist) or skip the step.

When launching `studio-playtester`: pass the `res://debug/…` path and the InputMap action recorded on the `F<n>` or the RFC. The playtester **plays** that scene; they do not build it and they do not use `call()` to assemble it. If that scene is missing, they must return `NEED_SETUP`, not invent a world. Order them to read `harness.md` from `godot-agent-kit` **before** writing a `.gd`. On return, the playtest diff may only touch `agent/` (flows, out). If it touched `src/`, `scenes/`, or `debug/`, that is a **process FAIL** — ask for a revert.

A typo, an `@export`, or a bug with repro and 1–3 files: **this chat**, no new RFC. New feature or moving scope: spec (PRD/RFC) or `/manage-changes`.

## 1. Startup (you ask and you run commands)

If the user wants a game / new feature and artifacts are missing, **do not wait** for them to type the slash: execute the matching command (read `commands/*.md` in the kit or `.cursor/commands/` in the project).

If the repo already has PRD/RULES, read them and `/workflow-status` if needed; do not regenerate artifacts.

Order for a **new game**:

1. Architecture Clean vs standard — **ask** (layered skill). No answer: do not scaffold.
2. Multiplayer — **ask** (AskQuestion if available) **before** copying `addons/mp_kit` or writing RPCs:
   - **No multiplayer** — do not install MpKit. No RPCs, no `MultiplayerSpawner`.
   - **Local / Wi-Fi** (same device or LAN) — `MpKit.host()` listen-server (the host is a player).
   - **Online** (internet / VPS) — **dedicated server** in the same project: `MpKit.host_dedicated()`, clients `join(ip)`. Develop dedicated + clients from day one. Steam/WebRTC/matchmaking only if the product asks later. Do not pretend a listen server behind NAT is online.
   No answer: do not copy the addon.
3. 2D / 3D — **ask** (or both).
   - **2D**: sprites via Aseprite MCP **only** if the user wants (references). Skill [godot-animation](../godot-animation/SKILL.md).
   - **3D**: **ask** if they want the Blender MCP ([official docs](https://www.blender.org/lab/mcp-server/)). If yes: install it, ask for references, export `.glb` into the game. If no: 3D placeholder. Guide: [assets.md](../godot-composition-first/assets.md).
4. `/create-prd` → `PRD.md` (for games: a short GDD; see that command). Document MP type and 2D/3D.
5. If style or refs already exist: `/create-visual-guide` → `VISUAL.md`. If not, **ask** before any visual pass.
6. `/verify-prd`
7. `/extract-features` → `FEATURES.md`
8. `/generate-rules` → `RULES.md` (must cite these skills; `godot-mp-kit` only if there is MP)
9. `/generate-rfcs` — first RFC = playable vertical slice, not endless infra. If they chose **online**, an RFC for dedicated glue + VPS export (not mixed with the gameplay slice; do not invent Steam).
10. `/test-strategy` only if the user wants tests or the PRD asks for them
11. Implement RFC by RFC with the pipeline below
12. `/workflow-status` when they ask where things stand

Research (Godot API, a pattern, an addon, a shader): `explore` subagent or a targeted read (Godot Shaders, Shadertoy). 2D sprites: **ask** if they want MCP/art and ask for references. If **3D**: **ask** and install the Blender MCP only with OK + references. The orchestrator summarizes; do not paste dumps.

Mid-work scope changes: `/manage-changes`.

## 2. One-RFC pipeline

One RFC at a time. Predecessors done.

Small cut (one component, one `@export`, no test scene that could cheat): the plan stays in this chat. Do not launch a tech lead.

Cut with a tree or with `res://debug/`:

```
orchestrator
  → studio-tech-lead     plan + tree + res://debug/   [no code]
  → the user sees the tree once and OKs
  → studio-developer     product + res://debug/
  → studio-reviewer      one pass
  → studio-playtester    plays that scene; does not ask for another OK
  → orchestrator         classifies the report and closes
```

Several developers only when the features do not share a scene. Never developer and reviewer at once on the same cut.

### FAIL return

Do not reopen the tech lead unless the cut or the test scene was framed wrong.

| Report | Returns to |
|--------|------------|
| The criterion failed, or the PNG shows something other than what was asked (a number changed, but what is on screen is not the thing named) | `studio-developer`, one correction |
| `res://debug/` already shows the outcome | `studio-reviewer` (the scene cheats) |
| Cache (`CACHE_STALE`) or the CLI could not run | This chat. One `--import`, then relaunch the playtester |
| Missing `res://debug/` (`NEED_SETUP`) | This chat completes the plan. The playtester does not invent it |

Closing the iteration **leaves a trace** every time (not optional): the `F<n>` in `FEATURES.md` with its criteria, and — if the `godot-studio-memory` skill is present — decision taken + next step. In a new chat, `/workflow-status` rebuilds from those files; with no trace, it rebuilds nothing.

The subagent prompt includes: repo path, RFC id, architecture style, **MP type** (none / local-Wi-Fi / online), compact rules, and to read PRD / FEATURES / RULES / VISUAL / that RFC.

Do not launch developer and reviewer in parallel on the same RFC. Tech-lead on independent RFCs may run in parallel.

Without the [file tree](file-tree.md) there is no “OK, implement”.

## 3. Do not

- Ship product features without PRD + RFC (except a pinpoint fix the user already scoped).
- One `studio-developer` “build the game”.
- Invent Clean layers if they chose standard, or the reverse.
- Copy `addons/mp_kit` if they chose no multiplayer.
- Treat a listen-server behind NAT as internet multiplayer.
- Put score, copy, or title netcode in `addons/mp_kit`.
- A second OK for playtest: the tree already included `res://debug/` and the action. A visual pass is still asked, and without `VISUAL.md` there is no look.
- A visual pass without style/references: do not invent a look.
- Install MCP (Aseprite, Blender, Engram) or create art without asking.
- Hardcoded feel. Choose Tween or `AnimationPlayer` per clip, not by habit. Juicy feel: `/add-juicy`, not a `World.gd` of particles.
- `enum` + `match` for actor states: `/add-state-machine`.
- Platformer without coyote/buffer: `/add-platformer-2d`, not a bare `is_on_floor()`.

## 4. Done when (exit checklist per iteration)

Do not close an iteration “by feel”. Verify:

- [ ] The project parses headless: `godot --headless --path . --quit` with no `SCRIPT ERROR` / `ERROR`.
- [ ] The feature scene runs with F5/F6 and the slice action is exercised.
- [ ] The `F<n>` names the scene (`res://debug/…` or the player scene), the InputMap action, and the observable. An RFC only if the cut is large.
- [ ] Every criterion has review evidence and, if there was a playtest, the flow under `res://agent/`.
- [ ] `FEATURES.md` updated; memory holds decision + next step if the skill is present.

The north star stays the same: the slice plays, each feature is a small scene/component/`Resource`, and a human can open the inspector and continue.
