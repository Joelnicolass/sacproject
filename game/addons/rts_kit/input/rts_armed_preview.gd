class_name RtsArmedPreview
extends Node

## While one of `modes` is armed, `hz` times a second it asks the game what a click at the pointer
## would answer (`answer`, read only: the same rule the server runs) and writes that answer to the
## state (`show_aim`): the cursor turns to "blocked" and the reason shows next to the pointer before
## the player clicks. It casts nothing, sends nothing and draws nothing.

@export var armed: RtsArmedCommand
@export var state: RtsCommandState
@export var pointer: RtsPointer
## The armed modes that get a preview (a building to place); empty = every non-order mode.
@export var modes: Array[StringName] = []
## Questions per second.
@export_range(1.0, 60.0, 1.0) var hz := 15.0

## The game's rule: `func(mode: StringName, payload: Variant, screen: Vector2, ground: Variant) ->
## Array` returning [status: StringName (&"" = it would start, else a refusal key), site: Node or
## null]. Unset: no preview.
var answer: Callable

var _since := 0.0


func _ready() -> void:
	if state:
		state.armed_changed.connect(_on_armed_changed)
	set_process(false)


func _on_armed_changed(kind: StringName, _icon: Texture2D) -> void:
	var on := _previews(kind)
	set_process(on)
	_since = 1.0
	if not on and state:
		state.show_aim(&"", null)


func _process(delta: float) -> void:
	_since += delta
	if _since < 1.0 / hz:
		return
	_since = 0.0
	preview()


## Asks now and shows the answer (a test may call it to skip the wait).
func preview() -> void:
	if state == null:
		return
	if armed == null or not answer.is_valid() or not _previews(armed.mode) or pointer == null:
		state.show_aim(&"", null)
		return
	var screen := pointer.pointer_now()
	var result: Variant = answer.call(armed.mode, armed.payload, screen, pointer.ground_at(screen))
	if result is Array and (result as Array).size() >= 2:
		var site: Variant = result[1]
		state.show_aim(StringName(result[0]), site as Node if site is Node else null)
	else:
		state.show_aim(&"", null)


func _previews(kind: StringName) -> bool:
	if kind == &"" or (armed and armed.commands and armed.commands.has_id(kind)):
		return false
	return modes.is_empty() or modes.has(kind)
