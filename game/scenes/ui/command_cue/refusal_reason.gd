class_name RefusalReason
extends Label

## The words of why a command is or would be refused, next to the pointer: «Muy lejos», «Falta
## maná», «Ese manantial ya tiene torre»… It shows every refusal the server or the HUD says
## (CommandLog.said, for `flash_s` seconds) and, while an armed structure would be refused at the
## pointer, that reason for as long as it holds (CommandLog.aim_status). The words come from
## `Refusal.text(key)` (data/i18n/strings.csv). It decides no reason and draws no icon (CommandCue
## does). CommandCue hands it its `command_log` and `probe` when they are not set here.

@export var command_log: CommandLog
@export var probe: TargetProbe
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
	if command_log != null:
		bind(command_log, probe)


## Listens to `source` (once) and places the words at the pointer of `pointer`.
func bind(source: CommandLog, pointer: TargetProbe) -> void:
	if probe == null:
		probe = pointer
	if source == null or source.said.is_connected(_on_said):
		return
	command_log = source
	source.said.connect(_on_said)
	source.aim_changed.connect(_on_aim_changed)


func _on_said(message: String, _cue: StringName) -> void:
	if not command_log.is_reason(message):
		return
	_flash_text = Refusal.text(StringName(message))
	_flash_left = flash_s
	_refresh()


func _on_aim_changed(_status: StringName, _site: Node3D) -> void:
	_refresh()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_refresh()
	_place()


## The flash wins while it lasts; then the live reason of the armed icon, if any.
func _refresh() -> void:
	var words := _flash_text if _flash_left > 0.0 else ""
	if words.is_empty() and command_log != null and not command_log.armed.is_empty():
		words = (
			Refusal.text(command_log.aim_status) if not command_log.aim_status.is_empty() else ""
		)
	text = words
	visible = not words.is_empty()
	set_process(visible)
	_place()


func _place() -> void:
	var at := probe.pointer_now() if probe != null else get_viewport().get_mouse_position()
	position = at + offset_px
