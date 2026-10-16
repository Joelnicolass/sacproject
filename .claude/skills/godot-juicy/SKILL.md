---
name: godot-juicy
description: >-
  Hace jugoso (juicy) un juego Godot 4: camera shake, hit-stop, squash de
  impacto, partículas, post-process, screen flash, knockback visual, hooks de
  SFX. Packed scenes, knobs @export, solo presentación. Usar cuando el usuario
  quiere juicy, jugoso, feel, camera shake, VFX, GPUParticles, feedback de
  golpe, post-process o /add-juicy. No es puntaje ni QA visual de UI.
---

# Godot — juicy (jugoso)

Presentación que hace que un hit, un salto o un UI **se sienta jugoso**. No es gameplay (vidas, spawn, puntaje) ni un pase de fidelidad UI ([godot-visual-qa](../godot-visual-qa/SKILL.md)).

Composición: [godot-composition-first](../godot-composition-first/SKILL.md). Motion de escala/pose: [godot-animation](../godot-animation/SKILL.md) (12 principios; Tween **o** `AnimationPlayer` según el clip). Shaders: [assets.md](../godot-composition-first/assets.md). Recetas: [catalog.md](catalog.md). Pedido acotado: command `/add-juicy`.

**No** hace falta un subagente aparte: implementa `studio-developer` (o este chat si son 1–3 archivos) con esta skill.

## Qué es / qué no

| Sí | No |
|----|----|
| Shake de cámara, flash, partículas, pass de post, squash, hit-stop **visual**, whoosh de SFX | Mutar HP, spawn, puntaje, autoridad de red |
| Un packed scene / hijo por efecto | Un `World.gd` que tira partículas + puntúa |
| Knobs `@export` (trauma, decay, amount, duration) | Magia en el `.gd` |
| Cada peer pinta lo jugoso | Meter juicy en `addons/mp_kit` o en el snapshot de reglas |

En MP: el servidor decide **si** hubo hit; el cliente (y el listen host) pintan el FX. Mismo código 1P (`OfflineMultiplayerPeer`).

## Elegí herramienta (por efecto)

No hay default. Evaluá el clip, igual que en animación.

| Efecto | Herramienta típica |
|--------|-------------------|
| Squash, punch, fade, knockback **visual** | Tween + `@export`, o `AnimationPlayer` si hay varios tracks |
| Cámara | Hijo `CameraShake` sobre `Camera2D`/`Camera3D` (`offset` / `h_offset`, no pelear con el follow) |
| Impacto / dust / sparks | `GPUParticles2D` / `GPUParticles3D` one-shot (o CPU si el presupuesto es bajo) |
| Flash / viñeta / hit tint | `ColorRect` + modulate, o un pass |
| Bloom, grain, chromatic, freeze-frame look | Pass packed (`BackBufferCopy` + `ColorRect` + shader). Catálogo Godot Shaders / port Shadertoy |
| Hit-stop | Corto y **local al visual** (pausar `AnimationPlayer` / partículas). `Engine.time_scale` solo en 1P y con restore; en MP es peligroso |
| Audio | `AudioStreamPlayer` hermano, no adentro del shader |

Combinar está bien: shake + partículas + squash en el mismo evento, cada uno un nodo.

## Árbol

```
Actor
├── Visual
├── JuicyHit.tscn      # squash / flash local
└── ImpactBurst.tscn   # GPUParticles one-shot

World
├── Camera2D
│   └── CameraShake    # offset
└── PostFxStack        # CanvasLayer; un hijo = un pass
```

El actor **orquesta** (`play_hit()` llama hijos). El hijo no lee HP.

## Intensidad

Si el usuario no dice cuánto: preguntá **sutil / medio / mucho**. Default **medio**. No apiles 8 pases “porque juicy”.

## Anti-patrones

- `Engine.time_scale = 0.2` en dedicated o en todos los peers sin criterio.
- Mover `global_position` de la cámara para el shake (rompe follow).
- Shader de otro título (CRT, wrap) copiado “de memoria”.
- FX que spawnea gameplay o suma puntos.
- Un autoload `JuicyManager` para el hit de *este* actor.

Playtest: lo jugoso se **juega** (skill `godot-playtest`, módulo [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)), no se unit-testea.
