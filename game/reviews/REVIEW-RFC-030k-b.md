# REVIEW-RFC-030k-b (F149): congelar a distancia

Reviewer, una pasada, 2026-10-17. **Veredicto: CHANGES** (1 bloqueante).

## Criterios
C1 a C5 PASS: 1250/1500, deriva 0, deshielo de 0 o 150, rotura en 104/105 y `f149` igual en los 3 modos (`f148` sin cambios).

## Fidelidad y diseño
- **Fidelidad:** PASS en el radio, la memoria de tocados, el blanco pedido y el mismo bando, la salpicadura, la congelación al final del update, `tryFreezeWithCooldown`, el `ceil` con épsilon, el deshielo sin derribo, los edificios y los magos. Además, sacengine también rompe el hielo con una caída mayor que 0 (9037), y el port coincide.
- **Pose:** dueño único en `Afflictions._show`. PASS.
- **`frozen.tres`:** `damage_factor` 1, `cancels [stunned]`. PASS.
- **Refactor `ShotInFlight`:** neutro. PASS.
- **Determinismo y red:** PASS.
- **Reglas:** PASS.

## Bloqueante
- **B1:** `StoneLook` (Petrified) e `IceLook` (Frozen) escriben los dos los overrides de material de `Tilt/Mesh`, y cada `_undress` pone en null todo lo que haya, también lo que no puso él (`stone_look.gd:60-65`).
  - **Cuándo falla:** en un cliente, si en el mismo tick se rompe el hielo y llega la mirada del Basilisk, `_show` viste de piedra y después desviste por `Frozen._shown(false)`. El resultado es un cuerpo petrificado sin el look de piedra.
  - **Por qué bloquea:** son dos dueños del mismo estado.
  - **Arreglo:** un solo dueño del look del mesh, derivado del mask, igual que se hizo con `clip_pose`.

## Menores
- **N1:** el comentario de `frozen.gd` sobre la caída es incorrecto.
- **N2:** `Frozen.cooldown_ticks()` no se usa en ningún lado.
- **N3:** `FrostWave` usa duck typing sobre el disparo.
- **N4:** `get_node("Health")` sin `_or_null`.
- **N5:** `log_touches` está en true por defecto.
- **N6:** el épsilon del `ceil` puede fallar en casos borde.

## Playtest (playtester, una corrida)
PASS en los 4 puntos (`agent/out/pt149/play/`): la onda en vuelo, los dos congelados con tinte gris azulado y deriva 0, el deshielo con esquirlas, y el dardo que rompe el hielo de E1. No se ve en una captura que E1 vuelva a moverse, porque es pacifista.
