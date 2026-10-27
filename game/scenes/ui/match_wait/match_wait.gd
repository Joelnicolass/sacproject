class_name MatchWait
extends Control

## The banner of a networked match that has not started yet: «Esperando jugadores k/n» while the door of the match
## (`Mp.gate()`) waits for the seats to load their world. On the listen host, with at least one client loaded, «Empezar ya»
## starts the match with the players who are in. Runs while the tree is paused (PROCESS_MODE_ALWAYS in the scene).
## Not: who may sit or when the match starts (the gate); network code of its own.

## The count line: `%d/%d` = seats loaded / seats the match waits for (the listen host is not counted).
@export var count_key := &"UI_MATCH_WAIT_COUNT"


func _ready() -> void:
	visible = false
	var gate := Mp.gate()
	if gate == null:
		return
	gate.waiting_changed.connect(_on_waiting_changed)
	%StartNow.pressed.connect(_on_start_now)
	_on_waiting_changed(gate.is_waiting(), gate.loaded_count(), gate.expected_count())


func _on_waiting_changed(waiting: bool, loaded: int, expected: int) -> void:
	visible = waiting
	%Count.text = tr(count_key) % [loaded, expected]
	## The gate only lets the listen host start early, and only with one client loaded; a client's gate says no.
	%StartNow.visible = waiting and Mp.is_server() and Mp.gate().can_start_now()


func _on_start_now() -> void:
	Mp.gate().start_now()
