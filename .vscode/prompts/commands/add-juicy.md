Add **juicy** feel to an event that already exists in the **game’s Godot project**: hit, land, jump, death, UI confirm, spawn, etc.

This is **not** a rules feature (`/implement-feature`). **Not** a UI pass vs `VISUAL.md` (`studio-visual`). **Does not** invent new gameplay.

Load: `godot-juicy` (how + [catalog.md](../skills/godot-juicy/catalog.md)), `godot-animation` (12 principles; Tween or `AnimationPlayer` per clip), `godot-composition-first` (one pass = packed scene). If there is MP: juicy is **local presentation**; the server does not “simulate” shake.

If `godot-studio-workflow` is loaded: orchestrator → juicy piece tree (this chat if 1–3 files; else `studio-tech-lead`) → OK → `studio-developer` → ask playtest. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which **event** (hit, land, UI, idle camera…).
2. Intensity: subtle / medium / a lot (default medium).
3. 2D or 3D. Extra art (VFX sprites): placeholder unless OK + references.

Pick **few** effects that reinforce that verb. Do not stack bloom + grain + CRT + shake + 3 bursts “because juicy”.

## 2. Plan

Tree: one child or packed per effect (`CameraShake`, `JuicyHit`, `ImpactBurst`, a pass in `PostFxStack`). What is Tween, what is `AnimationPlayer`, what is `GPUParticles`, what is a shader (catalog first). Every knob `@export`.

Juicy does not read HP or spawn simulation actors.

## 3. Implement

Follow [godot-juicy](../skills/godot-juicy/SKILL.md). The container calls `play_*` on the event gameplay **already** validates.

## 4. Done when

- The event feels juicy in F5/F6 (one action).
- Intensity is tuned in the inspector.
- On MP, a guest sees the FX without having simulated the damage.
