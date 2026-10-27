# Cambios de FsmKit

## 0.2.0

Desde **0.1.0**, todo lo de abajo. Si tu proyecto tiene 0.1.0, revisá primero los cuatro cambios que rompen.

**Rompe**

1. `transition` y `transition_to` llevan un payload: `transition(state_name, next_payload := null)` en `FsmMachine` y `FsmState`, `transition_to(next, next_payload := null)`. Un script que overridea una de ellas con la firma de 0.1.0 (un argumento) ya no parsea ("the function signature doesn't match the parent"). Arreglo: agregá `next_payload: Variant = null`.
2. Pedir el estado actual ya no es un no-op. `transition(&"<actual>")` mantiene el estado (sin `exit` / `enter`) pero pone `payload`, le llama `apply_payload(payload)` y emite `transitioned(from, from, payload)`. `state_changed` sigue saliendo solo en un cambio real. Si lo llamabas en cada frame "para asegurarte", llamalo solo cuando el estado tiene que cambiar, o mirá `is_in()` antes.
3. `actor` por defecto es el padre del machine, y el primer `enter` espera a que haya un actor y un estado. En 0.1.0 el machine entraba en `_ready` aunque `actor` fuera null.
4. El `transition()` de un estado es un pedido: pasa por `FsmMachine.request()` y `_request_transition()`. Por defecto dice que sí, así que nada cambia salvo que lo overrides. `transition()` / `transition_to()` del machine siguen siendo directos.

**Nuevo**

- `payload` en el machine, `apply_payload()` en el estado, la señal `transitioned(from_name, to_name, next_payload)`, `notify_actor_ready()`.
- `autostart` (prendido por defecto) y `start(state, payload)`: arrancar cuando decís, en el estado que decís. `is_started()`.
- `_request_transition(next, payload) -> bool`: el dueño del estado decide el pedido de un estado.
- `step_physics(delta)` / `step_process(delta)`: avanzar el estado actual vos (con `run_physics` / `run_process` apagados).
- `current_name()`, `is_in(name)`.
- Un estado agregado después de que el machine está listo también recibe su `machine`.
- Tests: `addons/fsm_kit/tests/fsm_test_runner.gd`.

## 0.1.0

`FsmMachine` + hijos `FsmState`, transición por nombre de nodo, `actor` inyectado, `state_changed`.
