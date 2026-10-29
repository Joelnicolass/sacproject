# REVIEW F9 — Orden de movimiento en la partida

Fecha: 2026-10-08
Reviewer: studio-reviewer (pase de solo lectura; el orquestador copió este informe).
Alcance aceptado: una sola orden `move`, con el id del mago en el puesto del wizard y en el de la criatura. La ejecuta `ObjectState.update`. Destino +40 en X de sac. El archivo solo existe si la distancia al spawn de F8 es mayor que 5. Tope frame 300. Godot convierte `Vector3(x, z, y)`.
Arquitectura: estándar. Multijugador: online dedicado. Sin RFC.

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios F9 | PASS |
| F8 no regresiona | PASS |
| Arquitectura | PASS |
| Alcance | PASS |
| Escena debug (trampa) | PASS |
| Idioma | PASS |

Bloqueantes: ninguno.
El playtest puede correr. F9 no se cierra hasta que Enter en `res://debug/move_order.tscn` muestre «coincide» y el mago quede en `Vector3(1507.67, 16.9, 1555.94)`, fuera del encuadre `(1275, 53.4, 1275)`.

## Criterios F9 — PASS

`game/cache/tick_move_ref.txt`: n=49, order=move, x=1507.67, y=1555.94, z=16.9. Distancia al spawn de F8: 5.25.

- La orden se manda una sola vez, fuera del bloque de F8. El id 0 no llama a `addCommand`.
- Al superar 5, escribe y apaga la ventana. Al tope, stderr y sin archivo.
- `move_order_check.gd` arranca en «Pendiente». Sin archivo o con distancia menor o igual a 5, no mueve al mago.
- «coincide» no está horneado en la escena.

## Nits

Si el archivo no se puede escribir, la ventana igual se cierra. Los mensajes de consola de sacengine siguen en inglés.
