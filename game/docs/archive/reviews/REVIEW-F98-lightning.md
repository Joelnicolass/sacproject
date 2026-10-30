# REVIEW F98 — Rayo fiel de Lightning (RFC-029, corte 029d)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: NEEDS WORK, por un bloqueante chico.**

- **Fidelidad: PASS.** Coincide con sacengine en segmentos, caja, cantidad de rayos, `changeShapeDelay`, `travelDelay`, frames, malla, textura `ltn2`, energía y origen.
- **Medido sin capturas:** 1,050 s de vida, 63 cuadros, 10 cambios de forma y 0,00 m de desvío al final. Es exacto respecto del original.
- **Red: PASS por código.** Un RPC unreliable por rayo, que el dedicado no dibuja. Si el blanco falta, no hay crash. El criterio 2 (dedicado + cliente) todavía no tiene evidencia.
- **Determinismo: PASS.** Usa `_beam_rng` propio.
- **Pool y memoria: PASS.** Tope de 6 y material compartido.

## Bloqueante
API de producto que solo usa el harness: `FxBus.beams_playing()` y `BeamFx.shape_changes()`, `start_point()`, `age()` e `is_playing()`. Hay que sacarlas y que `beam_watch` observe por su cuenta.

## Nits
- La búsqueda de luz está duplicada.
- Alocaciones por cuadro en `_add_ribbon`.
- `_ready` repite propiedades que ya define el `.tscn`.
- Falta un warning de configuración cuando no hay `type`.

## Follow-ups (RFC de simulación)
- El daño y las chispas deberían llegar en el frame 12.
- Redireccionar el rayo con `collideRay`.

## Decisiones del orquestador
Una ronda corta del developer para el bloqueante y los dos primeros nits. Después, playtest con dedicado + cliente y una vista lateral para el usuario.
