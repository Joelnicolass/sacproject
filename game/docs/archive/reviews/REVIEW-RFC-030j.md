# REVIEW-RFC-030j (F121): empuje, vórtice, implosión y Tumbling

Reviewer, una pasada, 2026-10-17. **Veredicto: CHANGES** (2 bloqueantes).

## Criterios
| # | Criterio | Veredicto | Notas |
|---|---|---|---|
| 1 | Squall: 15·\|dir_xz\| en 40 ticks | PASS | 14,94 contra 14,94 |
| 2 | Vortick: ápice y desplazamiento ±10 % | PASS (Druid) | El Trogg da 124 % porque choca en el aire; solo da 5,72/5,70 |
| 3 | Aturdido (hitFloor+getUp)·2 | PASS | 286 = (67+76)·2 |
| 4 | Flurry: la réplica ±10 % | FAIL tal como está escrito | 1,30 contra 0,04 m; el tirón queda 10,2 % corto porque las cápsulas no se atraviesan |
| 5 | Determinismo | PASS (log) | f121 9fc5b190 en los 3 modos |

## Bloqueantes
- **B1** (`tumbling.gd:121`, `:150`): el aterrizaje solo mira `BodyNudge.ground_y`. Un cuerpo que cae sobre un edificio u otra cápsula queda en tumbo para siempre: con `holds`, sin IA y con `vz` creciendo hasta unos −82, y el daño de caída se vuelve enorme. Arreglo: aterrizar también con `is_on_floor()` o con cualquier contacto de suelo.
- **B2**: la divergencia de las cápsulas está solo en el Resultado. Hay que pasarla a «Divergencias declaradas» y reformular el criterio 4.

## Menores
- **m1**: dos escritores de `Tilt.rotation:z` (`Stunned` y `Tumbling`); conviene un único dueño de la pose derivado de `clip_role`.
- **m2**: `amba` y `cita` no tienen `sweep=true`; sacengine usa `lineOfSightWithoutSide` en los dos.
- **m3**: divergencias que faltan declarar:
  - un petrificado no se puede arrojar;
  - Rockform aterriza con `fall_down`;
  - `WIZARD_STUN_ANIM_SLOTS` no aplica `fasterStandupTimes` (7 magos).
- **m4**: `BodySeparation.resolve` desvía el tumbo; no está declarado.
- **m5**: rutas por string (`"Afflictions/Tumbling"`, `"Collision"`, `"Flight"`) en lugar de sockets.
- **m6**: documentación desactualizada:
  - `editor_description` de `f121_push.tscn`;
  - encabezado de `run_pt121.sh`;
  - el RFC todavía dice f119_push.

## Otros
- **Un dueño:** `Afflictions.steer` es el único dueño de la velocidad en tumbo, y `holds`/`immobilized` siguen siendo de `Afflictions`. Las escrituras directas a `position` son fieles a sacengine.
- **`Stunned.fall_down` y `previous`:** es un parche de orden leve. Un cliente que entra tarde cuenta knock en vez de hitFloor (solo cosmético). Recomendado: un bit o tipo propio para `fallen`.
- **Red:** Vortex e Implosion corren solo en el servidor, bajo `Shots` sin replicarse. Es correcto.
- **Tamaño:** `unit_body.gd` sigue en 1040 líneas.
- **Harness:** sin uso de API prohibida.
