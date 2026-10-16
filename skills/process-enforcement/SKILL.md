---
name: process-enforcement
description: Obliga flujo Godot Studio y reglas de desarrollo
user-invocable: true
disable-model-invocation: true
---

Usa esta skill al inicio de **cualquier** implementación del proyecto.

## Objetivo

Esta skill es un bloqueo de proceso: si el agente o la sesión intenta saltarse pasos, debe detenerse y pedir replanificación antes de escribir más código. El objetivo es impedir que el proyecto vuelva a quedar con escenas vacías, unidades de costado, comportamientos sin evidencia ni visuales hardcodeados.

Ningún cambio de gameplay/arquitectura se cierra sin:
- plan con árbol de archivos,
- escena de validación en `res://debug/`,
- criterios observables,
- revisión y evidencia,
- verificación real con el binario correcto de Godot.

## Reglas obligatorias

1. **No código antes del plan**
   Si el cambio supera 1–3 archivos o toca una escena jugable, primero: plan, árbol de archivos y criterios observables.
   No iniciar con “arreglo rápido”, “sólo unas líneas” ni “ya sé qué falla”.

2. **Pipeline fijo (sin atajos)**
   `studio-tech-lead` → (OK del usuario una sola vez) → `studio-developer` → `studio-reviewer` → `studio-playtester` (si existe el módulo).
   Si el agente intenta saltar la revisión o el playtest, debe responder con una pausa de proceso y no seguir codeando.

3. **Composición y editor primero**
   - Priorizar nodos, PackedScenes, `@export`, `%UniqueName`.
   - No instanciar por código lo que debe editarse en `.tscn`.
   - Los mundos deben poder abrirse y editarse en el editor sin quedar vacíos.
   - No hardcodear “feel” ni offsets visuales por actor si pueden vivir en datos/Resource.

4. **Autoridad de red**
   En online dedicado: servidor simula reglas, cliente envía intents y presenta.
   Ningún cliente debe inventar autoridad ni propagar estados sin validación del servidor.

5. **Datos del original como verdad**
   Para stats/animaciones/roles de clip, usar export del original (`cache/data/*`, `export_stats.py`), no aproximaciones inventadas.
   Si no hay evidencia del original, documentar la ausencia y no cerrar la tarea como “resuelta”.

6. **Escena debug obligatoria por corte**
   Cada corte define:
   - ruta `res://debug/...`,
   - acción InputMap,
   - resultado observable.
   Si no hay `res://debug/` o la escena no valida el criterio, la iteración queda incompleta.

7. **Cierre mínimo de calidad**
   - Parse headless sin `SCRIPT ERROR`.
   - Criterios de `FEATURES.md` con evidencia.
   - Si falta cobertura, documentar explícitamente qué quedó pendiente y por qué.
   - Validar con el binario real del proyecto (`~/Downloads/Godot-7.app/Contents/MacOS/Godot`).

## Bloqueo de proceso

Si alguna de estas condiciones ocurre, el agente debe interrumpir y volver al plan, no seguir a lo loco:
- se propone tocar más de 3 archivos sin árbol ni criterios,
- se quiere ocultar la escena en el editor o generar el mundo por código puro,
- se quiere “reparar” animación/orientación sin comparar con fuente/export,
- se intenta cerrar una feature sin parse headless ni evidencia del playtest.

## Checklist de ejecución

- [ ] Leí `PRD.md`, `RULES.md`, `FEATURES.md` y skill contexts activos.
- [ ] Definí corte acotado con árbol de archivos.
- [ ] Definí escena debug + InputMap + observables.
- [ ] Implementé sin romper composición/editor-first.
- [ ] Pasé parse headless con el binario correcto de Godot.
- [ ] Dejé evidencia en revisión/playtest y actualicé `FEATURES.md`.

