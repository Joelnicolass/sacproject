# REVIEW F6 — Tick idle comparado con sacengine

Fecha: 2026-10-08
Reviewer: studio-reviewer (pase de solo lectura; el orquestador copió este informe).
Alcance aceptado: stub idle. Velocidad 0 y vida 1 en ambos lados. No es paridad de combate. No llama `ObjectState.update`. `state.d` no se reescribe.
Arquitectura: estándar. Multijugador: online dedicado (`host_dedicated`). Sin RFC.

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios F6 | PASS |
| Arquitectura | PASS |
| Alcance | PASS |
| Escena debug (trampa) | PASS |
| Idioma | PASS |

Bloqueantes de código: ninguno.
El playtest puede correr.

## Criterios F6 — PASS

FEATURES.md: tras N ticks, posición y vida coinciden con sacengine. En `res://debug/idle_tick.tscn`, `check_tick` muestra «coincide».

Evidencia:

- `sacengine/source/options.d`: `dumpIdleTick = -1` y `dumpIdleOut = ""`. Una partida normal no entra al dump.
- `sacengine/source/app.d`: `--dump-idle-tick=` y `--dump-idle-out=` se leen en `applySettings`. En `run`, `writeIdleTickDump` se llama justo después de `applySettings` y antes de `loadAudio` y `B.initialize`.
- El stub deja `x=y=z=0`, `life=1`, `speed=0`, y en el bucle solo hace `y += speed/fps` con velocidad 0. Escribe `n`, `order=idle`, `x`, `y`, `z`, `life` y devuelve 0. No llama `ObjectState.update`.
- `game/cache/tick_ref.txt`: `n=60`, `order=idle`, `x=0`, `y=0`, `z=0`, `life=1`. `game/.gitignore` ignora `cache/`.
- `game/scenes/world/idle_order.tres`: `step_per_tick = 0`, `start = (0,0,0)`, `life = 1`, `order_name = idle`.
- `tick_check.gd` lee `n`, avanza `start.y` sumando `step_per_tick` y compara posición y vida con `is_equal_approx`.

## Arquitectura — PASS

Estándar. Tipo en `TickOrder` + `idle_order.tres`. `IdleTick` instancia High Noon, `TickCheck` compara y `%Verdict` pinta. Sin RPC ni reglas de Sacrifice en `addons/mp_kit`. La comparación no usa la física de Godot.

## Alcance — PASS

Stub aceptado. No reescribe `state.d`. No mueve mallas. `high_noon` no cita el tick.

Observación, no bloqueante: sacengine suma `speed/fps` y Godot suma `step_per_tick`. Con ambos en 0 el resultado es el mismo.

## Escena debug — PASS

El texto guardado es «Pendiente». «coincide» solo se asigna dentro de `_compare`, y `_compare` solo corre con `check_tick`.

## Idioma — PASS

«Pendiente», «coincide», «no coincide», «falta la referencia». Nodos y la acción en inglés.

## Nits

- `_compare` no exige `order=idle` ni `order.order_name`.
- El sello de runtime headless lo corre el orquestador después de este informe.
