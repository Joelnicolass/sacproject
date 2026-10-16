Add **2D platformer forgiveness** (coyote, jump buffer, apex, corner, lift) to the player that already exists — or scaffold a thin `CharacterBody2D` + `PlatMotor`.

This is **not** a score/level feature (`/implement-feature` if the scope is “world 1-1”). **Not** juicy (`/add-juicy` is squash/VFX). **Do not** copy Celeste dash/stamina unless the product asks.

Load: `godot-platformer-2d` (+ [forgiveness.md](../skills/godot-platformer-2d/forgiveness.md)), `godot-composition-first`. States: `/add-state-machine` if the actor splits into Idle/Air/Wall. InputMap: `move_left` / `move_right` / `jump`.

If `addons/plat_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT plat_kit
```

Enable **PlatKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if 1–3 files; else `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Is there already a player `CharacterBody2D`? Only tune / replace jump?
2. Wall jump? Default **no**.
3. Dash / one-way / stamina? Default **no** (glue; see catalog).
4. Window intensity: tight / medium / generous (default medium: coyote 0.08, buffer 0.12).

## 2. Plan

```
Player (CharacterBody2D)
├── CollisionShape2D
├── Visual
└── PlatMotor
```

Knobs in the inspector. If there is an FSM, `read_input = false` and the state feeds `axis` / `request_jump()`. In MP the host calls `tick`; the guest does not simulate.

## 3. Implement

Follow [godot-platformer-2d](../skills/godot-platformer-2d/SKILL.md). Do not duplicate `move_and_slide` on the body and the motor.

## 4. Done when

- F6: jump after leaving a ledge (coyote) and jump slightly before landing (buffer).
- A ceiling corner does not stall the jump if `jump_corner_pixels` > 0.
- Tunable in the inspector. No invented dash/stamina.
