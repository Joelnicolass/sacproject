# REVIEW F8 — Posición tras frames de ObjectState

Fecha: 2026-10-08
Reviewer: studio-reviewer (pase de solo lectura; el orquestador copió este informe).
Alcance aceptado: la posición sale de `ObjectState.update` vía `controller.run()`. No es un bucle `speed/fps`. `state.d` no se reescribe. F6 y F7 siguen. Godot convierte una sola vez con `Vector3(x, z, y)` y no resta la base otra vez.
Arquitectura: estándar. Multijugador: online dedicado. Sin RFC.

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios F8 | PASS |
| F6/F7 no regresionan | PASS |
| Arquitectura | PASS |
| Alcance | PASS |
| Escena debug (trampa) | PASS |
| Idioma | PASS |

Bloqueantes: ninguno.
El playtest puede correr. F8 no se cierra hasta que Enter en `res://debug/state_tick.tscn` muestre «coincide» y el mago quede en `Vector3(1502.47, 16.9, 1555.2)`, fuera del encuadre inicial.

## Criterios F8 — PASS

`game/cache/tick_state_ref.txt`: n=60, order=state, x=1502.47, y=1555.2, z=16.9.

- `dumpStateTick` queda en -1 si nadie pasa el flag.
- Los return de idle y advance siguen antes de audio. `writeStateTickDump` solo escribe.
- Junto a `controller.run()`, al llegar al frame se lee el mago del slot 0. Si el id es 0, no se inventa una posición y se apaga `eventManager.running`.
- `state_tick_check.gd` arranca en «Pendiente». Sin archivo: «falta la referencia». Si no cierra, no mueve al mago. Si cierra, `Vector3(x, z, y)` y la cámara en +(-14, 10, 14).
- `state_tick.tscn` no hornea «coincide». El subject es el Wizard.

## Nits

Si el archivo no se puede escribir, la ventana igual se cierra. Los mensajes de consola de sacengine siguen en inglés.
