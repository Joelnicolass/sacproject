---
name: godot-juicy
description: >-
  Makes a Godot 4 game juicy: camera shake, hit-stop, impact squash,
  particles, post-process, screen flash, knockback visuals, SFX hooks.
  Packed scenes, @export knobs, presentation only. Use when the user wants
  juicy, feel, camera shake, VFX, GPUParticles, hit feedback, post-process,
  or /add-juicy. Not score, not UI visual QA.
---

# Godot — juicy

Presentation that makes a hit, a jump, or UI **feel juicy**. Not gameplay (lives, spawn, score) and not a UI fidelity pass ([godot-visual-qa](../godot-visual-qa/SKILL.md)).

Composition: [godot-composition-first](../godot-composition-first/SKILL.md). Scale/pose motion: [godot-animation](../godot-animation/SKILL.md) (12 principles; Tween **or** `AnimationPlayer` per clip). Shaders: [assets.md](../godot-composition-first/assets.md). Recipes: [catalog.md](catalog.md). Bounded request: command `/add-juicy`.

**No** extra subagent: `studio-developer` implements (or this chat if 1–3 files) with this skill.

## What it is / is not

| Yes | No |
|-----|----|
| Camera shake, flash, particles, post pass, squash, **visual** hit-stop, SFX whoosh | Mutate HP, spawn, score, net authority |
| One packed scene / child per effect | A `World.gd` that emits particles **and** scores |
| `@export` knobs (trauma, decay, amount, duration) | Magic numbers in the `.gd` |
| Each peer paints juicy locally | Put juicy in `addons/mp_kit` or in the rules snapshot |

On MP: the server decides **whether** a hit happened; the client (and listen host) paint the FX. Same 1P code (`OfflineMultiplayerPeer`).

## Pick a tool (per effect)

No default. Evaluate the clip, same as animation.

| Effect | Typical tool |
|--------|----------------|
| Squash, punch, fade, **visual** knockback | Tween + `@export`, or `AnimationPlayer` if several tracks |
| Camera | Child `CameraShake` on `Camera2D`/`Camera3D` (`offset` / `h_offset`, do not fight follow) |
| Impact / dust / sparks | `GPUParticles2D` / `GPUParticles3D` one-shot (CPU if budget is low) |
| Flash / vignette / hit tint | `ColorRect` + modulate, or a pass |
| Bloom, grain, chromatic, freeze-frame look | Packed pass (`BackBufferCopy` + `ColorRect` + shader). Godot Shaders catalog / Shadertoy port |
| Hit-stop | Short and **local to the visual** (pause `AnimationPlayer` / particles). `Engine.time_scale` only in 1P and restore; dangerous on MP |
| Audio | Sibling `AudioStreamPlayer`, not inside the shader |

Combining is fine: shake + particles + squash on the same event, each a node.

## Tree

```
Actor
├── Visual
├── JuicyHit.tscn      # local squash / flash
└── ImpactBurst.tscn   # GPUParticles one-shot

World
├── Camera2D
│   └── CameraShake    # offset
└── PostFxStack        # CanvasLayer; one child = one pass
```

The actor **orchestrates** (`play_hit()` calls children). The child does not read HP.

## Intensity

If the user does not say how much: ask **subtle / medium / a lot**. Default **medium**. Do not stack 8 passes “because juicy”.

## Anti-patterns

- `Engine.time_scale = 0.2` on dedicated or on every peer with no policy.
- Moving the camera `global_position` for shake (breaks follow).
- A shader from another title (CRT, wrap) copied from memory.
- FX that spawns gameplay or adds score.
- An autoload `JuicyManager` for *this* actor’s hit.

Playtest: juicy is **played** (skill `godot-playtest`, [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) module), not unit-tested.
