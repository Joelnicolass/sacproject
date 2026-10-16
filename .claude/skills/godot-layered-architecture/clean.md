# Camino Clean — capas

Usar **solo** si el usuario eligió Clean (o el repo ya lo declara). Dependencias hacia adentro:

```
features (Nodes, .tscn, física, RPCs, spawners)
    → core (autoloads: sesión, eventos, director, glue de red)
        → domain (RefCounted: reglas de partida)
```

```
src/
  core/autoload/     # MatchRules.tres, GameEvents, GameSession, SceneDirector
  domain/            # trackers y resolvers puros (estado de ronda, no catálogos)
  features/<name>/   # scripts + escenas juntas
  shared/            # StateMachine, PostFx, Health
  resources/         # class_name + .tres (tipos de contenido)
addons/              # MpKit y plugins del framework (cero gameplay)
```

Nombres de fachada: `GameSession`, `GameEvents`, `SceneDirector`. No uses nombres de un título anterior.

`GameSession` autoload **solo** si tiene que sobrevivir el cambio de escena; si no, nodo bajo `Main`. Tests: [godot-testing](../godot-testing/SKILL.md).

### Domain

- `extends RefCounted`. `new()` en tests y en la sesión.
- Prohibido: `Node`, `Input`, `MultiplayerAPI`, `get_tree()`, `@rpc`, `await` de escena.
- Recibe números **o Resources de definición** por constructor. No lee autoloads en tests.
- **No** es el lugar de “cómo se ve el proyectil”. Eso es el `.tres`. Domain usa `data.damage`, no strings de tipo.

### Core

- **GameSession**: trackers por slot, `start` / `abort`, `submit_*`, `to_snapshot` / `apply_snapshot`. El cliente apaga el tick al aplicar snapshot.
- **GameEvents**: HUD/FX escuchan; el actor no guarda el score.
- **SceneDirector**: cambia de escena. Preferí swap de hijos de `World` y dejar `GUI` viva. No puntúa.
- **`MatchRules.tres`**: tunables de **ronda** (duración, vidas, layers). No 80 floats de cada enemigo.

1P = host local. Mismas reglas que 2P.

### Features

Nodos. `@rpc`, física, spawners. `@export var data: EnemyData`. No `match kind`.

### Shared + resources

Componentes de escena en `shared/`. Plantillas `.tres` en `resources/<familia>/`.
