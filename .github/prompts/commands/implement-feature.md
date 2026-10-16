Implement **one** gameplay feature in the **game’s Godot project**. Iterating a playable slice beats a PRD that defines the whole title.

This is **not** `/new-mp-feature` (that only scaffolds an MpKit actor). This is **not** `/implement-rfc` (that follows an RFC already written). If an RFC id already exists, use `/implement-rfc <id>`.

If `godot-studio-workflow` is loaded, the **orchestrator** (this chat) does not implement alone. Small cut (one component, no scene that could cheat): the plan stays in this chat. If there is a tree or `res://debug/`: `studio-tech-lead` → the user approves the cut **once** → `studio-developer` → `studio-reviewer` → `studio-playtester` on the scene named by the `F<n>`. Do not ask again whether to play. Visual pass: ask, and without `VISUAL.md` there is no look. GUT tester only if the user or RULES asked.

When the playtester returns, classify: broken criterion → developer, one correction; the debug scene already shows the outcome → reviewer; cache or CLI → this chat imports and relaunches; missing scene → `NEED_SETUP`, not a new tech lead.

Load `godot-layered-architecture` and `godot-composition-first`. Motion: `godot-animation`. Juicy feel on an event that already exists: `/add-juicy` + `godot-juicy`. FSM: `/add-state-machine` + `godot-fsm`. 2D platformer: `/add-platformer-2d` + `godot-platformer-2d`. If there is MP: `godot-mp-kit`. If not: do not load the kit.

## 1. Scope (before code)

If the request is vague, ask in one batch (AskQuestion if available):

1. What the player does / what you see. One or two sentences.
2. Where it lives (scene, actor, HUD). Clean vs standard is **already chosen**; do not change it.
3. Is there networking? If yes: local/Wi-Fi or online. If no: zero RPCs.
4. 2D / 3D. Art: placeholder unless OK + references.

Do not interview a full GDD. Do not run `/create-prd` or `/generate-rfcs` “just in case”.

Out of scope for **this** feature: write it down and do not build it.

If the cut crosses session + net + several worlds, propose a short RFC and `/implement-rfc`. If it is a component, HUD, a `.tres` type, a state: stay here. If you only want juicy feel on something that already hits: `/add-juicy`. If you only want an FSM or platformer forgiveness: `/add-state-machine` / `/add-platformer-2d`.

## 2. Artifacts (they grow, they are not regenerated)

- If `FEATURES.md` exists: append the next `F<n>` (IDs are append-only; never renumber). Acceptance criteria in 3–8 bullets.
- If it does not exist: create `FEATURES.md` **only** with this feature (F1). Do not invent F2–F20.
- If `PRD.md` exists: at most one line in scope / non-goals. Do not rewrite the GDD.
- No RFC required. If the user wants a written contract, a minimal `RFCs/RFC-NNN-<slug>.md` (goal + acceptance + tree).

Authority on conflict: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFC > this plan. If there is no PRD, FEATURES + RULES + what the user just scoped win.

## 3. Pipeline (same as a small RFC)

### Phase 1 — plan, no code

`studio-tech-lead` (or this chat if the cut is 1–3 files):

- File tree + responsibility map ([file-tree.md](../skills/godot-studio-workflow/file-tree.md))
- Test scene under `res://debug/`: easy initial state, criterion outcome not yet true, InputMap action. Written on the `F<n>` (or the RFC if there is a contract).
- What is `.tres`, what is a node, what is `@export`
- Motion: evaluate Tween vs `AnimationPlayer` (skill `godot-animation`); knobs in inspector or timeline
- Checklist in [adding-features.md](../skills/godot-layered-architecture/adding-features.md)

Show the tree. **Wait for OK** (more/fewer pieces?).

### Phase 2 — implement

`studio-developer` follows the plan. One node does not paint + spawn + score + change scene.

### Phase 3 — review

`studio-reviewer`: each FEATURES (or short RFC) criterion with evidence. One pass.

## 4. Done when

- The project parses headless (`godot --headless --path . --quit` with no `SCRIPT ERROR`).
- The feature is exercised in the editor (F5/F6, one action).
- Every `F<n>` criterion has evidence in the review.
- Timing / squash / feel is tuned in the inspector if there is animation.
- FEATURES.md has the `F<n>` and the rest of the product was not invented; decision + next step land in memory if the skill is present.
