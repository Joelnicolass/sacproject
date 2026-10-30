# REVIEW-RFC-030u-b (F158): el Yeti congela al golpear

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

## Revisión

- **Fidelidad:** PASS.
  - `was_frozen` se lee antes del daño y `connected` se emite aunque el golpe haga 0.
  - Hay una sola tirada, dentro de `Frozen._try`, y con enfriamiento 0 no se tira.
  - `cc_protected` toma en cuenta Life Shield.
- **`connected`:** no cambia ningún golpe existente. Con monto 0, antes tampoco salían `struck` ni el daño.
- **`class_name MeleeAttack`:** no choca con nada.
- **Un dueño:** PASS. `MeleeOnHit` escucha, `inflict` aplica y `Frozen` decide.
- **Life Shield:** ahora también protege de petrificar, fiel al `ccProtected` del original. Stun, tumbling y pulling no lo consultan.
- **Determinismo, red y reglas:** PASS. Solo cambió la línea de `f132`.

## Menores

- **M1:** en sacengine, `shielded` también incluye skinOfStone, etherealForm, fireform, protectiveSwarm y airShield. Hoy solo se modela Life Shield. Queda como deuda.
- **M2:** no se evalúa `isApplicable` del hechizo de la pasiva.
- **M3:** el loop recorre todas las pasivas; es equivalente mientras haya una sola on-hit.
- **M4:** el log no distingue «congela» de «sin tirada».
- **M5:** el harness solo lee. OK.
