# REVIEW-RFC-030n-a (F125): Boulderdash y Phoenix

Reviewer, una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

## Resultado

- **Fidelidad:** PASS.
  - Una sola tirada de puntería para las 3 piedras.
  - Alcance de 2·range.
  - El giro de ±3,5° se aplica después del movimiento, cuando `max(0, d−60)` cruza 0.
  - Caja de 0,7, filtro de blanco o bando, sin `sweep`.
  - Phoenix = `heat_ray_impact`.
- **Maná del Phoenix:** el comportamiento es correcto. B1 está a 47 m de `FountSouth`, así que regenera 33,33/s mientras arde, igual que en sacengine.
- **Neutralidad y RNG:** PASS.
- **Un dueño:** `spawn_data` tiene un solo escritor y `ShotSplit` es el único que gira la piedra. PASS.
- **Reglas y composición:** PASS.

## Menores

- **m1:** C2 pedía el maná final; se enmendó en el RFC para medir el drenaje. Hecho por el orquestador.
- **m2:** el final del alcance usa `>=` en el port y `<0` estricto en sacengine; un rayo de 80 m justos revienta un tick antes. Viene de antes de este corte.
- **m3:** las 3 piedras sortean su giro visual por separado; en sacengine lo comparten.
- **m4:** `pt125_watch.gd:46` lee el campo privado `_running`.
- **m5:** `volley` solo admite impares, y no está documentado.

## Playtest (una corrida)

PASS en los 4 puntos (`agent/out/pt125/play/`):
- el abanico se abre;
- cada Druid queda en 350;
- el Druid del Phoenix arde;
- nadie quedó dentro de rocas.

El pasto tapa las piedras en vuelo y a los Druids.
