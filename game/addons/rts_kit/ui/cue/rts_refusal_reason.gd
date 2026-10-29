class_name RtsRefusalReason
extends Label

## The words of why a command is or would be refused, next to the pointer. It shows every refusal the
## state says (RtsCommandState.said, for `flash_s` seconds) and, while the armed thing would be refused
## at the pointer, that reason for as long as it holds (aim_status). The words come from the cue set
## (RtsCueSet.reason_text). It decides no reason and draws no icon.

@export var state: RtsCommandState
@export var probe: RtsTargetProbe
## Seconds the words of a refused click stay.
@export var flash_s := 0.6
## Where the top-left corner of the words sits from the pointer (canvas pixels).
@export var offset_px := Vector2(24.0, 44.0)

var _flash_left := 0.0
var _flash_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	if state != null:
		bind(state, probe)


## Listens to `source` (once) and places the words at the pointer of `pointer_probe`.
func bind(source: RtsCommandState, pointer_probe: RtsTargetProbe) -> void:
	if probe == null:
		probe = pointer_probe
	if source == null or source.said.is_connected(_on_said):
		return
	state = source
	source.said.connect(_on_said)
	source.aim_changed.connect(_on_aim_changed)


func _on_said(message: String, _cue: StringName) -> void:
	if not state.is_reason(message):
		return
	_flash_text = _words(StringName(message))
	_flash_left = flash_s
	_refresh()


func _on_aim_changed(_status: StringName, _site: Node) -> void:
	_refresh()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_refresh()
	_place()


## The flash wins while it lasts; then the live reason of the armed thing, if any.
func _refresh() -> void:
	var words := _flash_text if _flash_left > 0.0 else ""
	if words.is_empty() and state != null and state.is_armed() and state.aim_status != &"":
		words = _words(state.aim_status)
	text = words
	visible = not words.is_empty()
	set_process(visible)
	_place()


func _words(key: StringName) -> String:
	return state.cues.reason_text(key) if state and state.cues else tr(String(key))


func _place() -> void:
	var at := probe.pointer_now() if probe != null else get_viewport().get_mouse_position()
	position = at + offset_px
