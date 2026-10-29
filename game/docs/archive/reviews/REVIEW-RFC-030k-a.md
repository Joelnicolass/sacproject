# REVIEW-RFC-030k-a (F122): veneno a distancia

Reviewer, una pasada, 2026-10-17. **Veredicto: CHANGES** (1 bloqueante, corregido por el orquestador).

## Bloqueante
- **B1:** `Poisoned.start` (`poisoned.gd:34-35`) era API de producto que solo usaba `debug/rules_suite.gd`. **Corregido:** `rules_suite` ahora llama `Poisoning.dose_body(..., Health.SPLASH_SPELL, 1)` y se quitaron `start`, `_HEALTH` y `FPS`. `rules_suite` da PASS.

## Por dimensión
- **Un dueño (PASS):** `Poisoning` deriva los 4 agregados de sus dosis vivas en cada consulta, sin contadores que se puedan desincronizar. Health, ManaPool y MeleeAttack le preguntan solo a él.
- **Fidelidad (PASS):**
  - `lifetime + 1`;
  - contagio: suma entera, frames restantes, enfriamiento `left + 180` solo al tocado, ida y vuelta;
  - bloqueo de maná con `frame == 120`;
  - resistencia dentro del `max`;
  - `regen·Πfreg`;
  - drain sin daño directo;
  - el edificio recibe daño directo.
- **Determinismo (PASS):** avanza por tick, sin RNG, con orden estable.
- **Red (PASS):** la simulación corre solo en el servidor; el cliente ve Health, ManaPool y FxBus replicados.
- **Reglas (PASS tras B1):** `unit_body.gd` sigue en 1040 líneas y los harnesses están limpios.

## Menores
1. Un portador en modo `dying` no contagia (en sacengine sí, 1 tick).
2. Con dosis de menos de 1/s, sacengine resetea `poisonRegeneration`; ningún dato actual lo produce.
3. `nerf_factor = 1.3` está duplicado (`poison_impact.gd` y `poison_cloud.gd`).
4. `PoisonImpact` usa `.call` y `get` sin tipo.
5. `f116` y `f117` quedan para la pasada `all` del cierre del RFC.
