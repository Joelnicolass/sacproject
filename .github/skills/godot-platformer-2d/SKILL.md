---
name: godot-platformer-2d
description: >-
  Adds Godot 4 2D platformer forgiveness (PlatKit): coyote time, jump
  buffer, halved gravity at jump apex, corner correction, lift momentum.
  Use when the user wants a platformer player, coyote, jump buffer,
  Celeste-like feel, or /add-platformer-2d. Not dash/stamina. Not 3D.
---

# Godot — 2D platformer (forgiveness)

2D movement feel that **widens** timing and position windows in the player’s favor. Not a level, not score, not Celeste.

Addon `addons/plat_kit/` (`PlatMotor` child of `CharacterBody2D`). Reference: [Celeste & Forgiveness](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html) (Maddy Thorson).

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project plat_kit
```

Enable **PlatKit**. Bounded request: `/add-platformer-2d`. States: [godot-fsm](../godot-fsm/SKILL.md). Land/jump juicy: `/add-juicy`. Squash motion: [godot-animation](../godot-animation/SKILL.md).

**Do not** copy the addon into a top-down, a 3D fighter, or a menu.

## In the addon (defaults)

| Trick | What it does | Knob |
|-------|----------------|------|
| Coyote time | Jump shortly after leaving a ledge | `coyote_time` |
| Jump buffer | Jump pressed in air is consumed on landing | `jump_buffer` |
| Apex gravity | Jump hold → half gravity near the peak | `apex_gravity_mult` |
| Jump corner | Ceiling clip → horizontal wiggle | `jump_corner_pixels` |
| Lift remember | Platform momentum for a few frames | `lift_remember` |
| Wall jump window | Extra pixels (off) | `wall_jump_enabled`, `wall_extra_pixels` |

`read_input = false` + `axis` / `request_jump()` when a state or the MP host feeds the motor.

## In the game (not the addon)

Celeste also does **title-specific** tricks. Documented in [forgiveness.md](forgiveness.md): dash corner, one-way pop, super wall-jump, stamina refund. Implement them as children / glue if the product asks. Do not put them in `plat_kit`.

## Tree

```
Player (CharacterBody2D)
├── CollisionShape2D
├── Visual
├── PlatMotor
└── States                 # optional, fsm_kit
    ├── Idle
    ├── Air
    └── Wall               # only if wall jump
```

## MP

Host (or 1P) runs `tick`. Guest interpolates the body. Guest input → `submit_*` → host `request_jump` / `axis`.

## Anti-patterns

- `is_on_floor()` + jump **without** coyote/buffer on a precision platformer.
- Copying Madeline (dash, stamina, crystals) “because of the article”.
- Motor on the `CharacterBody2D` script **and** another copy in a state.
- Autoload `PlayerController`.
