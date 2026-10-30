# REVIEW-RFC-030q (F128 Web pull, F154 Cage pull)

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: CHANGES** (1 bloqueante).

## Bloqueante

- **B1** (`afflictions/pulling.gd:~172-176`, `body_nudge.gd:14-26`): `Pull` deja pasar a un blanco petrificado o congelado sin escudo, como manda `sacspell.d:171`. Pero `BodyNudge.push` y la rama de «salida» no se protegen con `fixed`, mientras que sacengine hace `return` en `push`/`catapult` (8588-8590). Resultado: un cuerpo inmóvil se desliza. Hay que arreglarlo con una API del cuerpo o de la aflicción, no con un `if` suelto en `Pulling`.

## Fidelidad

PASS en todo lo demás:
- carga en el cuadro 27 que cobra 60, aunque no haya blanco;
- rayo de rebote;
- sin enfriamiento (`starts_cooldown`, por defecto en true, no cambia nada);
- tirones, ventana de 25, tirón extra, fin;
- el **vuelo libre entre ventanas es fiel** a sacengine: fuera de la ventana no se toca `fallingVelocity`. Mover los carriles fue un arreglo del banco, no un cambio de comportamiento.

## Un dueño, red y reglas

- **Un dueño:** PASS. `Pulling` es el único que mueve al blanco, usando `catapult`, `drive` y `push`. `drive` y `steer` no se pisan gracias a la prioridad −1. Los `cancels` cortan el tirón de forma idempotente.
- **Red:** PASS. El hilo se libera según el bit replicado.
- **Reglas:** PASS.

## Menores

1. Rama de salida sin `fixed` (es parte de B1).
2. En el tick de carga no se vuelve a chequear el maná; sacengine exige `mana >= coste`.
3. `PullThread.wait_ticks = 30` puede liberar el hilo antes de tiempo si hay mucha latencia.
4. `_forward` no se comparó con `facingQuaternion`.
