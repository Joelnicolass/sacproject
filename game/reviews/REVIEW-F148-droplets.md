# REVIEW F148 (030h3): gotas de la Abomination

**Veredicto: PASS.** Revisión corta, de solo lectura, guardada por el orquestador (2026-10-17).

- **Fidelidad:** coincide con `state.d:24441-24505`, `4838-4845` y `16442-16447`.
  - Las gotas también se sueltan en el tick del estallido.
  - Probabilidad 3/4 con velocidad inicial 0.
  - Si cae bajo el suelo, no hace daño.
  - Caja de 0,25 y 50 de daño directo a distancia, sin multiplicador del tirador.
  - Pega a cualquier bando y prioriza en el orden enemigo, neutral, aliado y luego distancia.
- **Determinismo:** la corriente de azar es estable (`["drops", "ShotN"]`). La elección de blanco usa el mínimo por (rango, distancia², nombre). El pool usa índices y nunca `instance_id`. El lint sigue limpio.
- **Un solo dueño:** `RangedShot` solo delega en el dropper y `DropletRain` es el único que mueve y daña las gotas.
- **Balance en `f117`:** es fiel. El Druid que corre hacia la Abomination atraviesa la cortina de gotas. Queda pendiente calibrar la cápsula del Druid contra la hitbox de sacengine, que es un tema general y no de este corte.
- **Knobs de debug:** `pacifist` duplica el tipo y `order_farthest` vive solo en debug.

## No bloqueantes
1. Los logs estaban encendidos en el producto. **El orquestador los corrigió:** `log_hits` ahora arranca en false y `ai_match` lo enciende. El digest de `f148` no cambió.
2. `active()` no tiene llamador.
3. Diferencias con `collisionTarget` de sacengine:
   - la distancia se mide al origen y no a la hitbox;
   - los edificios y cuerpos no vivos no absorben la gota (en sacengine ocupan el rango +3).
4. Fuera del mapa la gota se descarta a los 600 ticks, en vez de usar `fallLimit`.
5. `intersect_shape` con un tope de 8 resultados.
6. Las gotas que se ven no son las simuladas (deuda visual).
7. Tope de 1024 gotas.
