# REVIEW-RFC-030r-a (F129): Sticky bomb, PaceFactors, Clinging, LobAbility

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE** (sin bloqueantes).

## Fidelidad
PASS, verificada contra `state.d` y `stats.d`:
- 10 bombas.
- Dirección con gravedad + puntería + 0,2·uniformDirection, con `v` sin normalizar.
- Caja de 0,25 y g = 20.
- Solo se pega a criaturas enemigas que se pueden envenenar.
- Se suelta en el tick 601.
- Un aliado como blanco cuenta como suelo.
- ×0,75ⁿ.

## Un dueño
PASS.
- `PaceFactors` es el único escritor de `speed_factor` en unidades y magos. El doctor escribe directo, como rama declarada.
- `Clinging` es el único dueño de lo pegado.
- `windup()`: Pull da 54 y Breath 52.
- Firewalk da 150. Lo cubre `f126` (carril B) en `quick`, y su línea base no cambió (nota del orquestador sobre el menor 6).

## Determinismo
PASS.
- RNG `["lob", usuario, tick]` y producto ordenado por nombre.
- `--autostart --seed=2` en ventana es correcto: el tick absoluto es una clave por diseño. Enter corre el arranque 1 tick.

## Banco, red y reglas
PASS.
- `order` y `attack` existen solo en `debug/`.
- `Clinging:shown` se replica.
- `PaceFactors` corre solo en el servidor.

## Menores
1. El log `marcha` lee `global_position` dentro de `Clinging`; está detrás de `log_cling`.
2. `FRAME_TICKS` va después de los `@export`.
3. Divergencia: una criatura que no se puede pegar frena la bomba.
4. Dos usos en el mismo tick repetirían la ráfaga; hoy lo impide el enfriamiento.
5. Look placeholder.
6. Firewalk 150: cubierto por `f126` (ver arriba).

## Playtest (Sonnet, una corrida)
- Las bombas en vuelo se ven, aunque chicas.
- Pegadas en Druid1 y Trogg1: se ven solo por el tono, con cámara baja.
- Se sueltan a los 600 ticks y el factor vuelve a 1.
- El Druid avanza 0,133 m por tick contra 0,183 de base (×0,73, consistente con ×0,75). Además lo verifica `f129_expect` con ±2 %.
