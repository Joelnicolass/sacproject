---
description: "Agrega feel jugoso (shake, hit-stop, VFX, post) a un evento que ya existe en el juego Godot."
---

Agregá **juicy** (jugoso) a un evento que ya existe en el **proyecto Godot del juego**: hit, land, jump, muerte, confirm de UI, spawn, etc.

Esto **no** es una feature de reglas (`/implement-feature`). **No** es un pase UI vs `VISUAL.md` (`studio-visual`). **No** inventa gameplay nuevo.

Cargar: `godot-juicy` (cómo + [catalog.md](../skills/godot-juicy/catalog.md)), `godot-animation` (12 principios; Tween o `AnimationPlayer` según el clip), `godot-composition-first` (un pass = packed scene). Si hay MP: lo jugoso es **presentación local**; el servidor no “simula” el shake.

Si está `godot-studio-workflow`: orquestador → árbol de piezas juicy (este chat si 1–3 archivos; si no `studio-tech-lead`) → OK → `studio-developer` → preguntá playtest. Sin subagente extra.

## 1. Acotar

Si falta, preguntá en un lote:

1. Qué **evento** (hit, land, UI, cámara idle…).
2. Intensidad: sutil / medio / mucho (default medio).
3. 2D o 3D. Arte extra (sprites de VFX): placeholder salvo OK + referencias.

Elegí **pocos** efectos que refuercen ese verbo. No apiles bloom + grain + CRT + shake + 3 bursts “porque juicy”.

## 2. Plan

Árbol: un hijo o packed por efecto (`CameraShake`, `JuicyHit`, `ImpactBurst`, pass en `PostFxStack`). Qué es Tween, qué es `AnimationPlayer`, qué es `GPUParticles`, qué es shader (catálogo primero). Todos los knobs `@export`.

Lo jugoso no lee HP ni spawnea actores de simulación.

## 3. Implementar

Seguí [godot-juicy](../skills/godot-juicy/SKILL.md). El contenedor llama `play_*` en el evento que **ya** valida el gameplay.

## 4. Listo cuando

- El evento se siente jugoso en F5/F6 (una acción).
- Intensidad se tunnea en el inspector.
- En MP, un guest ve el FX sin haber simulado el daño.
