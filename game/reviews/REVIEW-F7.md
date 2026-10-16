# REVIEW F7 — Avance comparado con sacengine

Fecha: 2026-10-08
Reviewer: studio-reviewer (pase de solo lectura; el orquestador copió este informe).
Alcance aceptado: paso cinemático speed 3, fps 60, n 60, z = 3, vida 1, order advance. No es combate. No llama `ObjectState.update`. `state.d` no se reescribe. F6 sigue en ceros.
Arquitectura: estándar. Multijugador: online dedicado. Sin RFC.

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios F7 | PASS |
| F6 no regresiona | PASS |
| Arquitectura | PASS |
| Alcance | PASS |
| Escena debug (trampa) | PASS |
| Idioma | PASS |

Bloqueantes: ninguno.
El playtest puede correr. F7 no se cierra hasta que Enter en `res://debug/advance_tick.tscn` muestre «coincide», el mago corrido y el campesino quieto.

## Criterios F7 — PASS

- `dumpAdvanceTick` queda en -1 si nadie pasa el flag.
- `writeAdvanceTickDump` corre después del return del idle y antes de audio y de la ventana. Suma `speed/fps` en z con speed 3.
- Si los dos dumps vienen juntos, gana el idle.
- `game/cache/tick_advance_ref.txt`: n=60, order=advance, x=0, y=0, z=3, life=1.
- `advance_order.tres`: paso 0.05 en el eje (0, 0, 1).
- `tick_check.gd` exige que el `order` del archivo sea el de la orden. Solo si coincide suma el delta al mago. El rótulo guardado es «Pendiente».
- `advance_tick.tscn` apunta el subject al Wizard. El campesino no es subject.
- Sin `move_and_slide`. Sin reglas de Sacrifice en MpKit. `high_noon.gd` y `wizard.gd` no citan el avance.

## F6 — PASS

`tick_ref.txt` sigue en ceros con `order=idle`. `idle_tick.tscn` no asigna subject. Con paso 0 el mago no se mueve.

## Escena debug — PASS

«coincide» solo se asigna dentro de `_compare`, y `_compare` solo corre con `check_tick`.
