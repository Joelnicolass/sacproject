# REVIEW F112 — Datos y cuerpos del bestiario (RFC-030, corte 030a)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: NEEDS WORK.** Hay un solo bloqueante: el criterio 5.

## PASS
- **Niveles:** fieles a `computeDefaultSpells` en los 5 dioses, índice por índice.
- **Audit:** 51 criaturas jugables y 0 faltantes. Los 227 clips coinciden con el SXSK.
- **`bodies.json`:** las entradas viejas quedan idénticas; cambian solo las 35 nuevas.
- **`max_level = 1`:** el juego queda idéntico (`rules_suite` PASS; digest seed 7 sin cambio, con y sin NPC).
- **Git:** nada del original. El `.pyc` estaba staged; el orquestador lo sacó y agregó `__pycache__/` al `.gitignore`.
- **Galería:** escena heredada que solo pisa `@export`.

## Bloqueante
**Criterio 5.** Rhinok aparece cabeza abajo. Hellmouth, Netherfiend y Yeti, hundidos. Phoenix flota.
- **Causa:** el horneado toma la pose de `idle0` (offset 180), que en sacengine es un gesto. La pose de reposo real es `stance1` (slot 0, offset 176; `state.d:7957-7992`).
- **Corrección:** hornear desde `stance1`, no con 5 overrides.

## A corregir sin bloquear
- **`_export_all_frames`:** si falla, borrar los OBJ parciales. Al reusar, exigir que la cantidad de cuadros coincida con el SXSK; `bool_clip_ok` también tiene que comparar contra el SXSK.
- **Taurock NPC:** declarar el cambio de cuerpo al cerrar. Radio 0,711 → 0,986 y alcance 1,745 → 2,374 m. Afecta `village_taurock` y `ai_npc_load`.

## Nits
- `creature_level` también devuelve niveles de hechizos.
- Validar la cantidad de `v` del último OBJ.

## Decisiones del orquestador (2026-10-16)
- **Pose:** exportar `stance1` y hornear `pose_source` desde su cuadro 0, **solo para las 35 nuevas** en este corte. El loop de idle no cambia.
- **Fuera de este corte:** pasar las 16 viejas a `stance1` y usar `stance1` como idle en loop (con los `idle0..3` como gestos) va a RFC-023, el sistema de animaciones.
- **Phoenix:** si sigue flotando con `DFst`, queda marcado para 030e con criterio medido.
- **Rhinok:** verificarlo en captura (`Eds1` es el mismo tag que shoot y fly).
- **Export:** la robustez de `_export_all_frames` entra en esta misma ronda.
