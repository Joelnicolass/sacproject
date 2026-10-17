# REVIEW-RFC-030p-b (F153): Breath of life

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

## Fidelidad

- **Aliento:** `v = 60·(t−p)`, con tope en 60. Llega cuando v < 0,01 y en ese momento llama a `fastRevive`.
- **Blanco:** el alma se resuelve a su cadáver. Pide muerto, mismo slot, alma NORMAL/EMERGING y ≤ 40 m.
- **Revivir:** dura 150 ticks, sube 2/75 hasta 1,97 m y gira 2π. Al final quita el alma.
- **Preparación:** 52 ticks.

## Diseño

- **Un dueño:** PASS. `FastRevive` es el único que escribe mientras `is_taken`. `finish_revive` restaura la capa y el grupo. `windup()` queda en un solo lugar, con una bandera por escena; Protector y Halo no tienen preparación.
- **`match_command`:** el clic sobre almas y cadáveres solo se activa con esos flags.
- **Determinismo y reglas:** PASS. `f153` da `130a619b` en los 3 modos y las otras 12 líneas base no cambian.

## Menores

- **m1:** en red, `submit_ability` manda el path del `Soul`. Si no coincide en el cliente, falla en silencio. Hace falta un playtest en red.
- **m2:** no se vuelve a agregar a la selección. Está declarado.
- **m3:** la caída es por gravedad. Está declarado.
- **m4:** `GameData.ability` se consulta en cada clic.
- **m5:** el comentario de shoot1/shoot2 en `windup_from_clip` está mal.

## Playtest (Sonnet, una corrida)

PASS en los 5 puntos (`agent/out/pt153/play/`): rechazos sin gasto, subida y giro, de pie al final con 800 de vida y sin alma, y nadie dentro de estructuras. El aliento se ve, pero pálido y chico: R+G−2B da 67-239 en el pico, contra 3-13 en el fondo.
