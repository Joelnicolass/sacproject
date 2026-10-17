# REVIEW-RFC-030o-b (F152): preparación, Firewalking y Firewalk

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE** (sin bloqueantes).

## Revisión
- **Fidelidad:** PASS.
  - La preparación dura 150 ticks y cobra el maná aunque el efecto falle. El enfriamiento se pone solo si estaba en 0, y el corte de la preparación no gasta nada.
  - La caminata dura 60 cuadros: es lineal hasta 20 m y después va partida ±10 m sobre el suelo. Alcance: 200·0,75.
  - Mientras camina no recibe daño (`_can_be_damaged` → `is_targetable` + `hides`, equivale a `canDamage`), no se lo puede inmovilizar (`admit`) y no es obstáculo.
- **Un dueño:** PASS. `steer()` es el único que escribe la posición. `hides()` tiene un solo origen y los `cancels` están completos (R2).
- **Determinismo:** PASS. El enfriamiento, Stealth y Play Dead pasan a ticks de `MatchClock`, y las otras 10 líneas base quedan intactas.
- **Red:** PASS. La invisibilidad y la estela salen del bit replicado, y `WarpSnap` se aplica en el salto.
- **Reglas:** PASS. `unit_body.gd` sigue en 1040 líneas. Las acciones de banco `ability` y `stun` viven en `debug/` y llaman a API que el producto ya usa.

## Menores
- **N1:** `.call` dinámico en `bench_events.gd`.
- **N2:** el print de `ActiveAbility` sigue encendido (R6, se resuelve en 030v).
- **N3:** orden de los comentarios en `bench_event.gd`.
- **N4:** sin acción.

## Playtest (Sonnet, una corrida)
- **Mecánica:** PASS en los 4 puntos (`agent/out/pt152/play/`).
- **Legibilidad de la estela:** FAIL parcial. Se ve como una mancha naranja pálida de unos 130×30 px, con contraste de luminancia de ~1,07 contra el pasto.
