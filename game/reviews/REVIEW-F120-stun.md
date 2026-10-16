# REVIEW F120 (030i-a): estado común y aturdir (Flummox)

**Veredicto del código: PASS.** No hay bloqueantes. El revisor es de solo lectura; el orquestador guardó este informe el 2026-10-16.

## Criterios
| # | Criterio | Estado |
|---|---|---|
| 1 | Duración según el clip | PASS. Tabla verificada contra `creatures.json`: Druid 226, Earthfling 112, Flummox 116, Shrike en vuelo 96. |
| 2 | Vuelve a pelear | PASS |
| 3 | Enfriamiento | PASS |
| 4 | Sin filtro de bando, incluido el tirador | PASS |
| 5 | Cliente | Pendiente para el playtest |
| 6 | Regresiones (`f29`, `f25`, Play Dead) | Pendiente para el playtest |

## Fidelidad y diseño
- `canStun` cubierto (rock, targetable, taken, stunned). El orden aturdir → dañar es equivalente mientras el aturdido no cambie el daño. Un cuerpo muerto por la salpicadura no queda aturdido: `Afflictions` pone `shown = 0`.
- `Afflictions` es el único dueño. La fusión con `_playing_dead` se revisó línea por línea.
- Red: `shown` se replica con spawn y ON_CHANGE, y el Tween corre local.
- Determinismo: sin RNG nuevo.
- `unit_body.gd` tiene −6 líneas.
- El WORKAROUND del Tween está bien aislado.

## No bloqueantes (el orquestador pidió una corrección de N1, V1, V2, V4 y N5)
- **N1:** un híbrido aturdido despega o aterriza. `Flight.advance` sigue corriendo y una orden lo hace despegar acostado. En sacengine `movement` no cambia mientras dura el aturdido.
- **V1:** el Tween gira sin levantar el pivote, así que medio cuerpo se hunde.
- **V2:** si muere acostado, salta a 0 antes de `Corpse`.
- **V3:** cae de costado (eje z) y juega idle de pie. En el original cae hacia atrás. Queda para cuando haya clips o para `studio-visual`.
- **V4:** el lunge no se corta al aturdir.
- **N3:** `PathFollower` vuelve a planear la ruta mientras el cuerpo está aturdido.
- **N4:** un cliente que entra tarde ve el aturdido desde el principio.
- **N5:** falta el corte rápido `shown == 0`.
- **Declarar:** Play Dead ahora suma `has_fallen` y en el aire muestra idle.
- `ability_status` dice «Blanco inválido» cuando el cuerpo está aturdido.
- `StunImpact` encuentra el estado por la ruta `Afflictions/Stunned`.
- `Stunned` no tiene avisos de configuración.
