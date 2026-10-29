# REVIEW F137 (030i-b): petrificar y la mirada del Basilisk

**Veredicto: FAIL** (2 bloqueantes chicos). El revisor es de solo lectura; el orquestador guardó este informe (2026-10-16).

## Bloqueantes
- **B1. La duración se mide con `Engine.get_physics_frames()`, que sigue contando con el árbol en pausa.** En solo, una pausa de 30 s termina la piedra al reanudar, y el resultado deja de ser determinista si hay pausa. Hay que usar un contador por tick como `Stunned`. Además, sacengine usa `frame++>=lifetime` (`23760`), así que hoy dura un cuadro menos.
- **B2. Petrificar a un cuerpo en Rockform no lo saca de Rockform.** sacengine pone `mode=stunned` (`11631-11640`). En el port pasan dos cosas:
  - El daño queda en ×0,05·0,2 = ×0,01.
  - Al terminar, `knock` se rechaza por `is_rock_form` y no hay aturdido.

## Lo que pasa la review
- **Fidelidad a sacengine:** ccProtected, canBePetrified, la duración `min(10, 10000/máx)` con un mago en 2,5 s, la caja de 0,35 m y el filtro de impacto. El final hace `damageStun` 240 y suelta 32 rocas. El ×0,2 respeta el orden. La fórmula del gris va sobre sRGB, igual que en dagon (`deferred.d:269-292`).
- **Un dueño:** el ×0,2 se aplica una sola vez por golpe, también en melee y en guardianes. `drops_fliers` es la única regla de caída y gana sobre la retención de F120.
- **StoneLook:** solo re-viste cuando cambia la malla, usa un material compartido por material de origen y restaura con null. No pisa a otros sistemas.
- **Red:** `shown` se replica y no depende del orden. **Determinismo:** no hay RNG nuevo de simulación.
- **Composición:** perillas en `.tres` y `@export`, `unit_body` con 0 netas, el banco no viene resuelto.

## Sin evidencia todavía (queda para el playtest)
- Criterio 6: vuelve a pelear.
- Criterio 8: el cliente ve la piedra.

## No bloqueantes
- **N1:** sacengine dispara con las dos manos y el port con una (divergencia sin declarar).
- **N2:** no hay rocas al morir petrificado.
- **N3:** un híbrido tirado mientras está FLYING usa el aturdido de vuelo estando en el suelo.
- **N4:** la caché estática de StoneLook no se libera nunca.
- **N5:** dos StoneLook sobre la misma malla (Skin of Stone).
- **N6:** un cliente que entra tarde ve la pose de reposo.
- **N7:** falta el corte rápido en `drops_fliers` y `cc_protected`.
- **N8:** el doc de `flight.gd` quedó suelto.
- **N9:** el log de un edificio dice «no tiene Petrified». Además, el sweep salta el terreno.
- **N10:** dura un cuadro menos.
- **N11:** hay `.uid` sueltos.
