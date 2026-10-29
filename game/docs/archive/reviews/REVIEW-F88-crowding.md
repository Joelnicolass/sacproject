# REVIEW F88 — Apiñamiento en BodySeparation (RFC-027, corte 027d)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: PASS con nits.** No hay bloqueantes.

## Corridas del reviewer
- `rules_suite`: PASS en los 89 casos (incluye `crowd_150` y `village_separation_grid`).
- `ai_match` seed 1: digest `3678de90…`, igual al declarado. `sep_ms` medio: 0,47.
- `--sep=brute`: corre limpio; el digest cambia, como se esperaba.

## Fidelidad
- Las posiciones al inicio del tick son fieles a `proximity` (`state.d:29318-29328`). Antes de 027d, el port era el que se desviaba.
- No hay sorteo en pares que no se tocan, y eso es fiel a `boxesIntersect` estricto (`state.d:28435`, `util.d:168-175`).
- `make_way` es un desvío deliberado y documentado. El corte y el fixup originales se mantienen.

## Casos borde
- Enemigos y otros slots: correcto.
- Voladores, cadáveres y estructuras: sin cambios respecto de antes.

## Decisión D1 (orquestador)
- **Problema:** el desliz se aplica también a los magos, incluido el del jugador. El original los frena.
- **Decisión:** el desliz queda solo para el grupo `unit`. El mago del jugador no cambia su control, y el digest se re-siembra otra vez.

## Nits (todos en la ronda de corrección)
- **N1.** Documentar el re-archivado a mitad del tick.
- **N2.** `_ask_to_yield` tiene que respetar el vencimiento.
- **N3.** El barrido de `frame_budget` muta `_asks`/`_sides`: guardarlos y restaurarlos, o apagar `make_way` durante el barrido.
- **N4.** No pedir ceder a una criatura que finge estar muerta.
- **N5.** No pedir ceder a criaturas en guardia o con `ordered` llegadas a su casilla. Además, `crowd_150` devuelve y chequea `off_slot`.
- **N6.** La dirección del pedido vigente se actualiza con el caminante más reciente o el más cercano.
- **Doc de `use_grid`:** el «modo original» exige apagar también `make_way` y `wizard_passes_own`.
- **Deuda (en esta ronda):** extraer `MakeWay` como `RefCounted` estático, con A/B igual antes de los cambios de conducta.
