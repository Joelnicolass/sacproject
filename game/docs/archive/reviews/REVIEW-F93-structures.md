# REVIEW F93 — Inspeccionar y dañar estructuras (RFC-028, corte 028b)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: NEEDS WORK.** Un bloqueante (B1); el resto pasa o queda para el playtest.

## Corridas
- `rules_suite`: 88 PASS, 0 FAIL.
- `f93_inspect` y `f93_splash`: AGENT_OK. Druid 550; `jcc2_1` 250,1 (d = 2,726); `jfn1_2` 0/0.
- Regresión AGENT_OK y sin `SCRIPT ERROR`: `final_wrath_splash` (Ranger 255), `f78_deselect`, `f78_corpse`, `f80_cues`, `pt73w_house`. RSS ≤ 1,39 GB.

## Bloqueante
**B1.** `SplashDamage.box_distance` (`splash_damage.gd:44-63`) mide contra la colisión de `MapBuilding`, que está achicada 0,5 m por lado (`map_building.gd:163-164`). sacengine mide con `boxPointDistance(target.hitbox)`, es decir, con la caja del modelo (`_box`, la que ya usa el alcance de melé). Efecto estimado sobre el cactus: ~293–305 de daño fiel contra 250 medido. Además, el criterio es tautológico: el probe calcula el valor esperado con la misma función que prueba.

## Pendiente para el playtest
- Clic sobre el altar: sin barra, `inspected` null, la selección intacta.
- Edificio que cae mientras está inspeccionado: `inspected` null y sin errores.

## Nits
- **N1.** Caja rotada contra AABB del original: anotarlo como decisión.
- **N2.** Edificio de varias piezas: el port mide contra la caja unida; el original, contra el componente más cercano.
- **N3.** El inspector busca la barra por nombre; mejor un socket o `inspection_bar()`.
- **N4.** Un clic sobre un mago o un cadáver delante de una casa ahora inspecciona la casa.
- **N5.** `splash_probe._process` hace un `find_child` recursivo en cada cuadro, en todos los flows.
- **N6.** El valor esperado del probe es tautológico.

Composición, red, AgentKit y alcance: PASS.

## Decisiones del orquestador
- B1: corregir.
- N4: inspeccionar solo si el primer collider bajo el cursor es el edificio.
- N5 y N6: corregir en la misma ronda.
- N1: documentar.
- N2 y N3: quedan como deuda.
