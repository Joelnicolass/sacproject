# REVIEW-RFC-030l (F123): disparos de fuego

Reviewer, una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

## Criterios
- **C1 Tickferno:** 216,9 en 61 actualizaciones; maná 49,17. PASS.
- **C2 Pyromaniac:** 866,9 en 301, sin daño directo. PASS.
- **C3 Bombard:** 517,5 / 386 / 354; fuego visual de 61 ticks. PASS (el carril a 25 m es un desvío declarado).
- **C4 Vuelo:** sfba 49 y lffa 51 cuadros. PASS parcial: la parábola de la Bombard no tiene medición (M1).
- **C5 Determinismo:** `f123` da d7db648e en los 3 modos y `quick` PASS.

## Fidelidad
- `Fire`: `lifetime + 1`; orden daño, maná, partículas.
- `drainMana`: `max(0, …)`.
- sfba, lffa y cfba coinciden con `state.d`.
- `pierce_shield` saltea exactamente los escudos de 8962-8969: `damage_factor` (Rockform, Life Shield) y `_state_factor` (petrified). Se siguen aplicando la resistencia, el fuego amigo, el Guardian y el pasivo.

## Diseño
- `Burning` como su propio dueño es correcto: no hay agregados.
- El orden de recorrido es determinista.
- `ManaPool` como `class_name` no choca con nada.
- Reglas: PASS.

## Menores
- **M1** (`ranged_shot.gd:219-221`, `burn_impact.gd:46-49`): `traveled()` es API de producto que existe solo para el log del criterio 4 y se llama por duck typing. Además, en la Bombard no mide el tiempo de vuelo.
- **M2** (`health.gd:110`): si una Affliction trae un `damage_factor` que no es escudo (por ejemplo `frozen`), `pierce_shield` lo saltearía mal. Hay que documentar que el `damage_factor` de Affliction es solo de escudos, o separar un `shield_factor`.
- **M3** (`burning.gd:44`): no pone el fuego visual sobre un cuerpo que acaba de morir (sacengine sí). Depende de un helper de `rock_projectile.gd`.
- **M4** (`burn_impact.gd:58`): `mana.get("maximum")` sin tipo.
- **Nit:** el comentario de `damage_over_time.gd:10-11` contradice a `Burning`, que avanza solo.

## Playtest (orquestador)
FAIL visual: la partícula `fire` sale casi blanca y tapa el cuerpo y la barra; la Bombard no muestra explosión. Va en la ronda de corrección.
