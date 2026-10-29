class_name MpWaitingLabel
extends Label

## Put one in the match HUD (the MpWorld's Hud has one). While the match waits for its seats to load (the world is paused), it
## says so on every peer: "Waiting for players (1/4)". Hidden once the match runs, and solo. Not: starting it (MpStartButton,
## or the gate by itself once load_timeout_s passed).

## `%d` / `%d`: seats loaded / seats the match waits for.
@export var text_format: String = "Waiting for players (%d/%d)"

const CHECK_S := 0.25

var _since: float = CHECK_S


func _ready() -> void:
	## Shown while the gate keeps the world paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(delta: float) -> void:
	_since += delta
	if _since < CHECK_S:
		return
	_since = 0.0
	var gate := MpKit.gate
	visible = gate != null and MpKit.is_networked() and gate.is_waiting()
	if visible:
		text = text_format % [gate.loaded_count(), gate.expected_count()]
