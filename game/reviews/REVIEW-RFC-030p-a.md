# REVIEW-RFC-030p-a (F127): Halo of Earth

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

- **Fidelidad:** PASS.
  - 6 rocas en T+1.
  - Órbita con `cintp2`.
  - Persecución en el orden del motor; la llegada se mide antes del paso.
  - Choque, suelo y vida en el mismo orden que el motor.
  - Blanco: el más cercano, con línea de vista y que ninguna otra roca esté apuntando.
  - 600 de hechizo directo.
  - Si el Rhinok muere, las rocas sin blanco explotan sin daño.
- **`REGEN_SLACK`:** es razonable. Solo se aplica al golpe que mata, y lo que cubre es la regeneración real (211 = 200 + 11).
- **Un dueño:** PASS. El coordinador es el único que escribe la posición de las rocas, y `RangedShot` no las mueve.
- **`touching()`:** usa `_can_hit`.
- **Determinismo, red y reglas:** PASS. `spawn_shot` no rompe a ningún caller.

**Menores:**
1. El comentario `life_ticks` es engañoso.
2. Si el Rhinok muere antes de T+1, el coordinador termina. No está declarado.
3. El choque usa la cápsula con máscara 3, no cajas. No está declarado.
4. `REGEN_SLACK` podría calcularse a partir de `creatures.json`.
5. **Visual:** las rocas que persiguen quedan tapadas por el pasto.
6. `terrain.call` se usa por nombre.
7. El harness asume que `Shot1` es la roca 0.
8. Hay que renumerar las escenas de 030q y 030r en el RFC: `f126` y `f127` ya están usadas.

**Playtest (Sonnet, una corrida):**
- PASS: las 6 rocas orbitan y Druid1 recibe 600.
- El flow cortó a los 2 s, así que el segundo golpe, Trogg2 inmune y los no blancos quedaron cubiertos solo por el banco (`f127_expect` en PASS en los 3 modos).
- Con la cámara en picado, la persecución se ve apenas como un punto y el pasto la tapa.
