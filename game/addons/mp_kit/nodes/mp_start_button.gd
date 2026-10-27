class_name MpStartButton
extends Button

## Put one in the match HUD (the MpWorld's Hud has one). On a listen host whose match waits for seats, it starts the match with
## the players already loaded (`Mp.gate().start_now()`). Hidden everywhere else (a client, a dedicated, solo, a running match).
## Not: who may sit or when the match starts by itself (MpMatchGate: start_seats, load_timeout_s).

## `%d` / `%d`: clients loaded / clients the match waits for.
@export var text_format: String = "Start now (%d/%d)"

const CHECK_S := 0.25

var _since: float = CHECK_S


func _ready() -> void:
	## Shown while the gate keeps the world paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	pressed.connect(_start)


func _process(delta: float) -> void:
	_since += delta
	if _since < CHECK_S:
		return
	_since = 0.0
	var gate := MpKit.gate
	visible = gate != null and gate.can_start_now()
	if visible:
		text = text_format % [gate.loaded_count(), gate.expected_count()]


func _start() -> void:
	if MpKit.gate and MpKit.gate.start_now():
		visible = false
