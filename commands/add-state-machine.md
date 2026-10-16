Add a composition **state machine** to the **game’s Godot project**: `FsmState` children under an `FsmMachine`.

This is **not** a rules feature (`/implement-feature`) unless the new state **is** the scope. **Not** the platformer motor (`/add-platformer-2d`). **Does not** invent HP or score.

Load: `godot-fsm`, `godot-composition-first`. If the actor already moves as a 2D platformer: `godot-platformer-2d` (the motor is **another** child; states call it).

If `addons/fsm_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT fsm_kit
```

Enable **FsmKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if 1–3 files; else `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which actor / scene.
2. Which states (Idle, Move, Hurt, …). Few. Not a diagram of the whole title.
3. Is there already a `match` / enum? Replace it, do not duplicate.

## 2. Plan

```
Actor
└── States          # FsmMachine, actor = Actor
    ├── Idle
    ├── Move
    └── …
```

Each state = a small script extending `FsmState` **or** the addon script + overrides in a game `.gd`. Feel knobs on the actor / `PlatMotor` inspector, not magic numbers in `enter()`.

## 3. Implement

Follow [godot-fsm](../skills/godot-fsm/SKILL.md). `transition(&"Hurt")` by node name. The state does not spawn or score.

## 4. Done when

- F6: at least two states are entered and left (one action).
- Removing the `States` child turns the behavior off.
- No parallel `enum` left on the actor.
