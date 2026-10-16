---
description: "Agrega perdón de plataformas 2D (coyote, jump buffer, apex, corner, lift) con PlatKit."
---

Agregá **perdón de plataformas 2D** (coyote, jump buffer, apex, corner, lift) al jugador que ya existe — o scaffoldeá un `CharacterBody2D` flaco + `PlatMotor`.

Esto **no** es una feature de puntaje/niveles (`/implement-feature` si el alcance es “el mundo 1-1”). **No** es juicy (`/add-juicy` es squash/VFX). **No** copies dash/stamina de Celeste salvo que el producto los pida.

Cargar: `godot-platformer-2d` (+ [forgiveness.md](../skills/godot-platformer-2d/forgiveness.md)), `godot-composition-first`. Estados: `/add-state-machine` si el actor se parte en Idle/Air/Wall. InputMap: `move_left` / `move_right` / `jump`.

Si no está `addons/plat_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT plat_kit
```

Enable **PlatKit**. Si está `godot-studio-workflow`: orquestador → árbol (este chat si 1–3 archivos; si no `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Acotar

Si falta, preguntá en un lote:

1. ¿Ya hay un `CharacterBody2D` jugador? ¿Solo tunear / reemplazar el salto?
2. ¿Wall jump? Default **no**.
3. ¿Dash / one-way / stamina? Default **no** (glue; ver catálogo).
4. Intensidad de ventanas: tight / medio / generoso (default medio: coyote 0.08, buffer 0.12).

## 2. Plan

```
Player (CharacterBody2D)
├── CollisionShape2D
├── Visual
└── PlatMotor
```

Knobs en el inspector. Si hay FSM, `read_input = false` y el estado alimenta `axis` / `request_jump()`. En MP el host llama `tick`; el guest no simula.

## 3. Implementar

Seguí [godot-platformer-2d](../skills/godot-platformer-2d/SKILL.md). No dupliques `move_and_slide` en el body y en el motor.

## 4. Listo cuando

- F6: salto al dejar el borde (coyote) y jump ligeramente antes de aterrizar (buffer).
- Techo en esquina no traba el salto si `jump_corner_pixels` > 0.
- Se tunnea en el inspector. Sin dash/stamina inventados.
