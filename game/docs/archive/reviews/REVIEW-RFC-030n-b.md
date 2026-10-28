# REVIEW-RFC-030n-b (F151): Rhinok

Reviewer, una pasada, 2026-10-17. **Veredicto: CHANGES** (1 bloqueante). El playtest falla en lo visual.

## Bloqueante
- **B1** (`ranged_shot.gd:136-137` junto con `spike_impact.gd:35-37`): `RangedShot` revienta cuando cae por debajo de `_ground_height()`, que usa la máscara 1. Esa máscara incluye estructuras, altares, manantiales y map_building. El disparo vuela a 0,05 m del suelo, así que revienta contra esos obstáculos, y `SpikeImpact` trata cualquier `target == null` como alcance agotado: el blanco pedido recibe 500 aunque esté lejos. En sacengine el disparo solo termina por choque o por `remainingDistance`, y `getHeight` pasa por encima de los techos.

## Resto
- **Fidelidad:** PASS en el vuelo, el choque, `frame` 0, las franjas, la condición de estar sobre tierra y a ≤10 m, edificios incluidos y un golpe por anillo.
- **Un dueño:** PASS. Los aliados se saltean antes de Health.
- **Determinismo:** PASS. `MatchSeed.rng(["spikes"])` es una semilla derivada, solo para el visual y solo en el servidor.
- **Red:** acepta el riesgo R4.
- **Reglas:** PASS.

## Menores
- **m1:** la rama de alcance agotado no se ejercitó.
- **m2:** el watch lee `global_transform.origin`.
- **m3:** un blanco pedido que es aliado pasa por `_side_factor` (con fuego amigo puede quedar en 0); hay que declararlo.
- **m4:** el orden del log difiere.
- **m5:** unos 70 `FxBus.broadcast` por disparo, que en red pesa en ancho de banda.
- **m6:** la semilla visual sale del nombre del disparo, que puede repetirse.

## Playtest
- **Mecánica:** PASS. Vuela pegado al suelo, hace 450 a C0, el daño avanza anillo por anillo y C6 queda intacto.
- **Visual:** FAIL. Las púas se ven como puntitos oscuros sueltos, no hay nada vertical y desde arriba no se lee el anillo (`agent/out/pt151/pt/`).
