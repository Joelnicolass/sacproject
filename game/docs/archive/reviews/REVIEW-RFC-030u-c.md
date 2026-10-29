# REVIEW-RFC-030u-c (F159): el Dragon enreda al golpear

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

## Revisión
- **Fidelidad:** PASS.
  - `grasp`: no aplica a voladores; `numVines` +1 por cada golpe, y cada uno lleva su propio vencimiento.
  - Duración: `(mago 0,25 : 1000/vidaMáx)·40 s` en f32.
  - Mientras dura: `steer` pone xz en 0, sin regeneración, `ccProtected` y `fixed`.
- **`Afflictions.fixed()` es el único dueño:** lo usan `BodyNudge`, `unit_body` y `wizard_body`.
  - La nota del developer era incorrecta: `Tumbling.catapult` ya usa `BodyNudge.fixed`, así que un cuerpo enredado no sale arrojado. El orquestador corrigió el RFC.
- **`cc_ticks`:** la fórmula de `Frozen` se movió tal cual; `f149` da igual.
- **Regeneración:** las dos vías pasan por `Health.regenerate`. `healBlocked` y `shieldBlocked` no se bloquean; está declarado.
- **`coexists` + `cc_protects`:** el enredo convive con los demás estados y rechaza el aturdido y el congelado que lleguen mientras dura.
- **Determinismo y reglas:** PASS.

## Menores
- **M1:** nota sobre `Tumbling` en el RFC. **Corregido.**
- **M2:** `const TICKS` sin uso en `vined.gd`. **Borrado**, y `f132` sigue en `18bfca66`.
- **M3:** comentario histórico en `sac_float`.
- **M4:** el bucle sobre `_on()` está repetido en `Afflictions`. Opcional.

## Playtest (Sonnet, una corrida)
PASS en los 4 puntos.
- Las lianas se ven.
- El Jabberocky queda quieto (desvío 0) y sin regenerar durante 429 ticks exactos, aunque tenga orden de moverse.
- Al terminar camina y vuelve a regenerar. Las lianas se retraen de a poco (35 ticks después del fin todavía queda una mancha).
- Nadie dentro de rocas ni estructuras.
