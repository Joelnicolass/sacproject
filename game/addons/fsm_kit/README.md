# FsmKit

Máquina de estados por **composición**: un `FsmMachine` y hijos `FsmState`. **Cero** reglas de partida, puntaje o copy. No hay autoload.

El actor es un contenedor flaco. Los estados **no** hacen `get_parent()` como API: el machine inyecta `actor`.

## Instalar

```bash
./install.sh --addon /path/to/godot-project fsm_kit
```

Habilitá el plugin **FsmKit** (tipos `FsmMachine` / `FsmState` en Create Node). Tools → `FsmKit: Add machine under selection`.

## Árbol

```
Actor (CharacterBody2D / …)
├── Visual
└── States          # FsmMachine, @export actor = Actor, initial_state = Idle
    ├── Idle        # FsmState
    ├── Move
    └── Hurt
```

`transition(&"Hurt")` busca el **nombre del nodo**. Cada estado overridea `enter` / `exit` / `update` / `physics_update` / `handle_input`.

`transition(&"Hurt", payload)` lleva datos genéricos (un hitbox, un objetivo); el kit no los interpreta y el estado lee `machine.payload`. Pedir otra vez el estado actual con otro payload no hace exit / enter: el estado recibe `apply_payload(payload)`. La señal `transitioned(from, to, payload)` sale en cada transición, también en una repetición (`state_changed`, solo en un cambio real).

## Arranque

Con `autostart` prendido (por defecto) el machine entra solo a `initial_state` (o a su primer hijo `FsmState`) en cuanto tiene un estado y un actor (`actor` por defecto es el padre). Si los estados o el actor llegan después, llamá `notify_actor_ready()` cuando existan.

Con `autostart` apagado no corre nada hasta que llamás `start(state, payload)`: un actor que primero se arma, un enemigo de un pool, un personaje que carga de un save, un jugador que entra a mitad de partida en el estado que dice la red.

```gdscript
machine.start($States/Hurt, {"animate": false})   # una vez; false si todavía no hay estado o actor
```

## Quién cambia el estado

| Quién | Llamada | Qué pasa |
|---|---|---|
| El dueño (el actor, el juego) | `machine.transition(&"Hurt", payload)` o `transition_to(nodo, payload)` | Cambia ya |
| Un estado | `transition(&"Hurt", payload)` (el suyo) | Un pedido: decide `FsmMachine._request_transition(next, payload)`. Por defecto dice que sí y el estado cambia ya |

Overrideá `_request_transition` (un script que `extends FsmMachine`) cuando el estado es de otro: un valor que replica la red, un replay, un tutorial que solo deja algunos pasos. Escribí donde vive el estado y devolvé `false`; el dueño llama `transition_to()` después.

```gdscript
extends FsmMachine

func _request_transition(next: FsmState, next_payload: Variant) -> bool:
	if not multiplayer.is_server():
		return false          # decide el servidor; su valor replicado llama transition_to() acá
	return true
```

## Avanzarlo vos

El machine llama `physics_update` / `update` del estado actual desde su propio `_physics_process` / `_process`. Para avanzar en tu propio orden (un rollback, una simulación determinista, turnos, pausar un solo actor) apagá `run_physics` / `run_process` y llamá `step_physics(delta)` / `step_process(delta)` donde los necesites. Dejá el flag prendido **o** llamá el step, no las dos cosas: con las dos el estado corre dos veces.

## Leerlo

`current` (el nodo), `current_name()` (vacío antes de arrancar), `is_in(&"Hurt")`, `is_started()`, `payload`.

## Tests

```bash
godot --headless --path <proyecto> --script res://addons/fsm_kit/tests/fsm_test_runner.gd
```

`FSMKIT TESTS PASS (n)`. La primera vez en un proyecto, importalo una vez (`godot --headless --path <proyecto> --import`) para que se conozcan `FsmMachine` / `FsmState`.

Cambios entre versiones, y qué actualizar en tu proyecto: [CHANGELOG.md](CHANGELOG.md).

## No hagas

- Un `enum` + `match` de 200 líneas en el actor.
- Guardar HP / puntaje / spawn en un estado.
- Fork del addon por título.
