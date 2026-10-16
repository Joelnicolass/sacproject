# Patrones de composición (Godot 4)

## StateMachine

Addon `fsm_kit`: padre `FsmMachine` con `@export var initial_state: FsmState`. Hijos = estados. `transition(&"Hurt")` busca por nombre de nodo.

- `FsmState.enter` / `exit` / `update` / `physics_update`.
- El actor se **inyecta**: `@export var actor: Node`. No `machine.get_parent()` como API.
- No guardar score en un estado.
- Command: `/add-state-machine`.

Plataformas 2D (coyote, buffer): addon `plat_kit` / `/add-platformer-2d`. El motor es **otro** hijo.

## Health / Hitbox / Hurtbox

`Health` (nodo `class_name`): `max_hp` puede venir del Resource de tipo; `hp` actual en el nodo. `signal damaged(amount: int)` / `signal died`. El padre orquesta (animación, `queue_free`).

Hitbox / Hurtbox = `Area2D` packed scenes. Opcional: grupo `"hurtbox"` si el tipo exacto no importa; los sockets `@export` ganan.

## PostFx stack

```
PostFxStack (CanvasLayer, layer alta)
├── BloomPass.tscn     # BackBufferCopy + ColorRect + shader
└── GrainPass.tscn
```

- Orden de hijos = orden de composición.
- Gameplay **no** mete código en el shader de otro pass: tweenea el pass que corresponde.
- `mouse_filter = IGNORE`.
- Toggle: mostrar/ocultar el pass; no early-`return` en `fragment()` que deje el buffer en blanco.
- Fuente: Godot Shaders / Shadertoy portado. Ver [assets.md](assets.md).

## Actor con física

- Simulación en `_physics_process` (o `_integrate_forces` si es `RigidBody`).
- Look en hijos. Input en un catcher que usa InputMap y llama `apply_*` / `submit_*`.
- Si el body es `RigidBody`, `MpAuthority.freeze_rigid_proxy` en proxies. No asumas RigidBody en todo actor.

## Preview en editor

`@export_tool_button` para regenerar geometría. El preview no escribe `MatchRules` ni arranca ENet.

## Plantilla Resource + escena

```
projectile.tscn
projectile_fast.tres    # ProjectileData { damage, speed, scene? }
projectile_slow.tres
```

El arma exporta `ProjectileData`. Spawnea `data.scene` (o la escena única) y asigna `data`.

## Cuándo sí va en código

- Layers de física compartidas con las reglas.
- Autoridad multiplayer.
- Valores de **ronda** idénticos en host y guest.

Tipos: Resource. Look de instancia: escena. Runtime: nodo.
