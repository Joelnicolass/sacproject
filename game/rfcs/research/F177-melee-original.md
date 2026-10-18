# F177 — ¿Tiembla el original en una melé de grupo?

Fecha: 2026-10-17. Solo investigación, sin cambios de juego.

## Resumen

- **Medido en el original: nada.** No se puede ejecutar el original en esta máquina (ver «Qué se intentó»).
- **Deducido de sacengine (con modelo numérico propio):** la aritmética de separación del original (tal como la reimplementa sacengine) **sí oscila en un ciclo de 2 ticks cuando una fila de cuerpos queda apretada desde los dos extremos**, con amplitud de 0,03-0,05 m en el hueco entre cuerpos. Una fila quieta o apretada desde un solo lado converge sin temblar. Lo que no se pudo deducir es si el original lo hace igual: depende de que el original use la foto del cuadro, igual que sacengine, algo que sacengine asume y yo no pude confirmar contra el ejecutable.
- El temblor de 2 ticks de s7 (0,02 m) es coherente con eso, así que no hay evidencia de que `make_way` lo cause; sí agrega deriva (a verificar con `make_way` apagado, ver recomendación).

## Qué se intentó (REA)

- `rea/` es un MCP/CLI de **análisis estático** (Ghidra, Hopper, IDA) más observación en tiempo de ejecución solo de Node/Electron/navegador. Snapshot existente: `.rea-snapshots/sacrifice-exe` (análisis del exe, sin trazas de ejecución).
- Sacrifice es un exe de Windows; en esta Mac no hay wine, CrossOver, Parallels ni VMware. No hay forma de correr el original y leer posiciones por cuadro, así que **no hay medición por tick del original** (ni distancia entre cuerpos, ni mínimo de superposición, ni cambios de sentido).
- No se instaló nada. Lo que falta para medir de verdad: (a) un entorno que ejecute el exe (wine/CrossOver o una VM Windows) más un lector de memoria o un hook (no está en REA para binarios nativos), o (b) decompilar con Ghidra (`.tools/ghidra_12.1.4_PUBLIC`) la rutina de colisión del exe y confirmar a mano que usa la foto del cuadro, el margen 0,2 y el tope de 5 m/s. (b) es viable sin instalar nada y es el camino recomendado si se quiere cerrar la duda.

## Análisis estático de sacengine (solo lectura, `sacengine/source/state.d`; sin copiar código)

**Orden y foto.**
- `update` (29328 y siguientes): al principio del cuadro `proximity.start()` y `eachByType!addToProximity` (28300-28313) guardan para cada criatura la caja (hitbox con rotación y animación del momento) y si es obstáculo. Después `eachMoving!updateCreature` (29333 aprox., bucle sobre el arreglo de objetos móviles) las actualiza **una por una en el orden del arreglo**.
- Cada criatura llama a `positionAfterCollision` (14446, invocada desde 14799) que consulta `state.proximity`: las cajas de los demás son **la foto del principio del cuadro**; la posición nueva de un vecino que ya se movió en este mismo cuadro **no se ve**. Es decir, el empuje es sobre la foto, no incremental. El orden de actualización por lo tanto no cambia el resultado (salvo `state.uniform(2)` en empates exactos de solapamiento).

**Dos pasadas (14541-14562).** Con margen `blockSlack = 0,2`:
1. *Bloqueo* (14543): la caja propia se **achica** 0,1 por lado. Contra cada obstáculo cuya caja completa solape, la criatura no avanza en ese eje (se queda en su posición vieja). Camina sin empuje: el que camina frena en seco, no hay desaceleración propia.
2. *Corrección* (14546-14562): la caja se **agranda** 0,1 por lado; cada solape (en el eje de menor penetración) suma un vector de «sacar»; se aplica **entero** (el solape completo de la caja agrandada, no la mitad) y luego se topa a `collisionFixupSpeed/updateFPS` = 5 m/s dividido por los cuadros por segundo (`stats.d:161`; 0,083 m por tick a 60). Sin amortiguación ni historia.
- Efecto: el equilibrio entre dos cuerpos es un hueco de 0,1 m entre cajas; el empuje es instantáneo hasta el tope. No hay estado de velocidad por empuje, lo que lo hace una corrección de posición pura.

**Cómo frena al que camina en la primera pasada.** `updateCreaturePosition` (14640 y siguientes): primero calcula la velocidad de marcha (aceleración/desaceleración propias, `meleeMoving` al 50 % de velocidad y aceleración, 14668-14671) y la posición nueva; la pasada de bloqueo después recorta esa posición contra la foto. La velocidad interna (`creatureState.speed`) **no se corta** por el bloqueo: sigue acumulada mientras la posición queda clavada.

**Aritmética de un par.** Dos cuerpos con hueco g < 0,1: cada uno corrige 0,1 - g hacia afuera sobre la foto, entonces el hueco nuevo es 0,2 - g, que ya es mayor a 0,1 y deja de corregir. Un par solo **no oscila** (rebota hacia afuera y se queda).

## Modelo numérico (réplica 1D de esa aritmética)

Script en el scratchpad de esta sesión (`sim.py`, no versionado; 1D, cajas de ancho 1, margen 0,1 por lado, foto del cuadro, tope 0,083 m/tick, caminata de 0,03-0,04 m/tick contra la fila). Resultados (huecos entre cajas en m, últimos 40 ticks):

| caso | resultado |
|---|---|
| fila de 4 quieta, huecos 0,02/0,04/0,03 | converge a 0,103/0,16/0,113 en un tick, amplitud 0 |
| apretada por un extremo (0,04 m/tick) | converge a 0,103/0,103/0,100, amplitud 0 |
| apretada por los dos extremos (0,03 y 0,04 m/tick), 4 cuerpos | **ciclo de 2 ticks**: huecos alternan 0,123/0,077/0,123, amplitud pico a pico **0,047 m** |
| ídem, fila de 6 | ciclo de 2 ticks, huecos 0,083 ↔ 0,117, amplitud **0,033 m**; mínimo en el transitorio -0,05 m |

Lectura: el modo alternante de una fila empujada desde ambos lados tiene valor propio -1 (lo mismo que dice F177 sobre la fila con empuje entero por cuerpo): un cuerpo interior recibe de los dos vecinos a la vez sobre la foto, sobrepasa, y el ciclo siguiente se invierte. La amplitud es del orden de lo que el port mide en su fila quieta (0,02 m); el hueco de equilibrio de 0,1 m del original contra el `rest_distance` del port (`BodySeparation.rest_distance`, `half_size(a)+half_size(b)+0,1`) coincide, y `FIXUP_SPEED` 5,0 y `BLOCK_SLACK` 0,2 del port son los del original.

## Qué NO se sabe

- Si el original usa la foto del cuadro o actualiza el vecino ya movido (sacengine es una reimplementación; lo asume).
- La forma real de la caja: el original usa el hitbox de la animación y la rotación (14446 en adelante pide `relativeHitbox`), no una caja fija. En melé, la animación de ataque cambia la caja cada cuadro, lo que mete variación propia que el port con caja fija no tiene.
- La superposición de -0,07 m del port: en el original el bloqueo permite hasta 0,1 m de penetración de las cajas completas (caja achicada 0,1), así que una superposición de ese orden en cajas cae **dentro de lo que el original admite**; el criterio de -0,05 m del plan es más estricto que el original.

## Recomendación

**Aceptar la oscilación de 2 ticks y no desviarse con la opción A** (amortiguar con `1/(k+1)`), con dos pasos baratos antes de cerrar:
1. Medir el s7 con `make_way` apagado: si el temblor de 2 ticks y la superposición quedan iguales, el temblor es de la aritmética heredada y el criterio (amplitud ≤ 0,03 m, superposición ≥ -0,05 m) se afloja a lo que admite el original (amplitud ~0,05 m, superposición hasta -0,1 m entre cajas). Si baja, el problema es `make_way`, que sí es un desvío del original y se corrige quitando o limitando ese desvío, no la separación.
2. Si se quiere certeza, decompilar con Ghidra la rutina de colisión del exe (ya hay snapshot) y confirmar foto del cuadro, margen 0,2 y tope 5 m/s. Es un trabajo acotado y no requiere instalar nada.

La opción A cambia todos los digests con dos cuerpos en contacto para arreglar algo que el original, según lo deducido, también hace; no se justifica sin evidencia medida en contra.
