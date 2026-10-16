---
name: godot-fsm
description: >-
  Agrega una máquina de estados por composición en Godot 4 (addon FsmKit:
  FsmMachine + hijos FsmState, socket actor, transición por nombre de nodo).
  Usar cuando el usuario quiere una state machine, FSM, estados Idle/Move/Hurt
  o /add-state-machine. No es un motor de plataformas. No son reglas de juego.
---

# Godot — máquina de estados (FsmKit)

Estados = **nodos hijos**, no un `enum` en el actor. Addon `addons/fsm_kit/` en el **proyecto del juego**.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project fsm_kit
```

Enable plugin **FsmKit**. Pedido acotado: `/add-state-machine`. Sin subagente extra: `studio-developer` (o este chat si 1–3 archivos).

Composición: [godot-composition-first](../godot-composition-first/SKILL.md). Plataformas 2D (coyote, buffer): [godot-platformer-2d](../godot-platformer-2d/SKILL.md) — el motor es **otro** hijo; los estados lo llaman.

## Árbol

```
Actor
├── Visual
├── PlatMotor          # opcional, otro addon
└── States             # FsmMachine
    ├── Idle
    ├── Move
    └── Hurt
```

- `@export var actor` en el machine (el contenedor).
- `@export var initial_state`.
- `transition(&"Hurt")` = nombre de nodo.
- El estado usa `actor` / `machine`, no `get_parent()` como API.

Al overridear `enter` / `exit`, llamá `super.enter()` si querés las señales.

## Qué va en un estado

| Sí | No |
|----|----|
| `enter` / `exit`, pedir `actor.velocity`, llamar `PlatMotor.request_jump()` | HP, puntaje, spawn, cambio de escena |
| `physics_update` de **este** verbo | `match kind` de todo el actor |
| Señales `entered` / `exited` | Autoload `StateManager` |

Un estado nuevo = un nodo nuevo, no un `elif` más.

## MP

La simulación (a qué estado pasás) es **autoridad del host**. Los guests interpolan / pintan. No metas FsmKit en `addons/mp_kit`.

## Anti-patrones

- Copiar `fsm_machine.gd` al feature “para cambiarlo un toque”.
- Estados que leen `Input` **y** aplican daño **y** spawnean.
- Machine como autoload global del título.
