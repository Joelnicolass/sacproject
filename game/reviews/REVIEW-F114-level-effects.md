# REVIEW F114 — Efectos del nivel en el mago (RFC-030, corte 030c)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: PASS con nits.** No hay bloqueantes de código.

## Fidelidad de `CastTime`
- Coincide con `sacspell.d:93-102`. La base es 81 = 1,35 × 60. El 19/20 del Basilisk se aplica antes del bono, con división entera.
- Ejemplos verificados a mano:

| Hechizo | Tiempo |
|---|---|
| Trogg | 0,2099 s |
| Basilisk, mago de nivel 9 | 0,4074 s |
| Styx | 2,0741 s |
| Manalith | 5,5556 s |
| Rhinok | sin cambio |

## Resto
- **Bono en `wizard_body`:** se acepta el desvío. Funciona en red, porque los máximos y los valores actuales se replican. El fantasma conserva el bono.
- **Nivel 1:** queda idéntico. Todas las entradas tienen `spell_order ≥ 100`, así que el bono da 0 y el valor vuelve sin tocar.
- **`rules_suite`:** 88 PASS y 1 FAIL (`crowd_150`). El FAIL es de 027d.
- **Escenas de debug que heredan el nivel 9:** son 14, más 4 de `agent/`. Ninguna mide al mago. `rock_hit` castea al doble de velocidad. `perf027_match` deja de ser comparable con su base.
- **Flows con aserciones viejas** («Vida 1500/1500 · Maná 1000»), 14 en total: `f20_solo`, `f20_client_a/b`, `pt20_solo`, `pt20_client_a/b`, `pt_full_complex_client_a/b`, `f31_online_client`, `pt31_online_client`, `final_online_a/b` y `late_join_a/b`.

## Nits
1. `CastTime.frames()` no tiene callers.
2. `f111_level3_james.tres` está en nivel 3 sin stats.
3. Rama sin bono contra rama con bono: falta un comentario.
4. Hay que declarar que el fantasma tarda más en volver (vida máxima 1950) y que la IA convoca criaturas de nivel alto.
5. La lista de escenas que heredan el nivel debería quedar en el cierre.

## Decisiones del orquestador
- Pasa a playtest con estas tareas:
  - Styx y «Maná 1900» en el HUD, con captura;
  - actualizar los 14 flows;
  - partida contra la IA con ventana.
- Nits 1–3: deuda menor.
- Nits 4 y 5: van en el cierre de FEATURES.
