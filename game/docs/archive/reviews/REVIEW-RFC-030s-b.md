# REVIEW-RFC-030s-b (F156): Bilemites

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: CHANGES**: un bloqueante de evidencia, no de código.

## Bloqueante

- **B1:** `spent()` no tiene evidencia. El criterio 3 dice «5.º toque → parado → se libera a los +30», pero ningún carril lo ejercita: los 10 ácaros pegan antes del 5.º salto. El código se ve correcto (`mite_hop.gd:58,72-92`, `ranged_shot.gd:131-133`). Para cerrarlo hace falta un carril sin blancos a ≤ 15 m, con `f156_expect` verificando tres cosas:
  - 5 saltos;
  - `parado` y `suelto` exactamente a +30;
  - que el nodo desaparezca.

## Revisión

- **Fidelidad:** PASS. 10 ácaros con g 20; salto con preferencia por el blanco pedido, en el orden de fórmulas del original; se para al 5.º toque; se pega por +481 con factor 0,8.
- **`intended`:** no cambia nada para Sticky ni para el aceite.
- **Un dueño:** PASS. `MiteHop` con `Terrain`.
- **Determinismo:** PASS. `uniform_direction` es compartido, en el mismo orden.
- **Reglas:** PASS.

## Menores

- **M1:** `hits_every_side` deja que el ácaro choque contra un cuerpo que no se puede envenenar, y ahí se pierde. En sacengine no choca. Hay que declararlo o filtrarlo.
- **M2:** `_intended` no aplica el filtro de altura ≤ 10.
- **M3:** estilo.
- **M4:** suelto el `.uid` de `pt155_watch`.
