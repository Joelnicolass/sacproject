---
name: godot-fsm
description: >-
  Adds a Godot 4 composition StateMachine (FsmKit addon: FsmMachine +
  FsmState children, actor socket, transition by node name). Use when the
  user wants a state machine, FSM, Idle/Move/Hurt states, or /add-state-machine.
  Not a platformer motor. Not gameplay rules.
---

# Godot — state machine (FsmKit)

States = **child nodes**, not an `enum` on the actor. Addon `addons/fsm_kit/` in the **game** project.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project fsm_kit
```

Enable plugin **FsmKit**. Bounded request: `/add-state-machine`. No extra subagent: `studio-developer` (or this chat if 1–3 files).

Composition: [godot-composition-first](../godot-composition-first/SKILL.md). 2D platformer (coyote, buffer): [godot-platformer-2d](../godot-platformer-2d/SKILL.md) — the motor is **another** child; states call it.

## Tree

```
Actor
├── Visual
├── PlatMotor          # optional, other addon
└── States             # FsmMachine
    ├── Idle
    ├── Move
    └── Hurt
```

- `@export var actor` on the machine (the container).
- `@export var initial_state`.
- `transition(&"Hurt")` = node name.
- The state uses `actor` / `machine`, not `get_parent()` as API.

When overriding `enter` / `exit`, call `super.enter()` if you want the signals.

## What belongs in a state

| Yes | No |
|-----|----|
| `enter` / `exit`, read `actor.velocity`, call `PlatMotor.request_jump()` | HP, score, spawn, scene change |
| `physics_update` for **this** verb | `match kind` for the whole actor |
| `entered` / `exited` signals | Autoload `StateManager` |

A new state = a new node, not another `elif`.

## MP

Simulation (which state you enter) is **host-authoritative**. Guests interpolate / paint. Do not put FsmKit in `addons/mp_kit`.

## Anti-patterns

- Copy `fsm_machine.gd` into a feature “to tweak it a bit”.
- States that read `Input` **and** apply damage **and** spawn.
- Machine as a global title autoload.
