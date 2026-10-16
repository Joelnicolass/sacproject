# Examples — arquitectura (genéricos)

Nada de un título concreto. Copiá y adaptá nombres al juego actual.

## Clean — sesión mínima

```gdscript
# src/core/autoload/game_session.gd
extends Node

var is_running: bool = false
var score: Dictionary = {}


func start(slots: Array) -> void:
	is_running = true
	score.clear()
	for slot in slots:
		score[int(slot)] = 0
	set_process(true)


func abort() -> void:
	is_running = false
	set_process(false)


func add_score(slot: int, delta: int) -> void:
	if not is_running:
		return
	score[slot] = int(score.get(slot, 0)) + delta


func to_snapshot() -> Dictionary:
	return {"is_running": is_running, "score": score.duplicate()}


func apply_snapshot(data: Dictionary) -> void:
	set_process(false)
	is_running = bool(data.get("is_running", false))
	score = data.get("score", {})
```

## Estándar — nodo Match en el mundo

```gdscript
# scenes/world/match.gd
extends Node

signal finished(winner_slot: int)

@export var round_seconds: float = 60.0

var time_left: float = 0.0
var lives: Dictionary = {}


func start(slots: Array) -> void:
	time_left = round_seconds
	lives.clear()
	for slot in slots:
		lives[int(slot)] = 3
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not MpKit.is_networked() or MpKit.is_server():
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			set_physics_process(false)
			finished.emit(0)
```
