@tool
class_name RtsCommandCue
extends Control

## What is drawn at the pointer instead of words: `Aim` = the icon of what is armed, a little below the
## cursor (`aim_offset_px`); `Invalid` = the refused icon, flashed when something is refused
## (RtsCommandState.said with a refusal cue) and held while the armed thing cannot take what lies under
## the pointer (an order over the sky) or would be refused there (aim_status); `Reason` = the words
## (RtsRefusalReason). Without a picture a plain circle / cross is drawn instead. Full screen, ignores
## the mouse.

@export var state: RtsCommandState
@export var cues: RtsCueSet
@export var probe: RtsTargetProbe
## Seconds the refused icon stays after a refusal.
@export var flash_s := 0.6
@export_group("Fallback")
@export var fallback_aim := Color(0.95, 0.85, 0.45, 0.9)
@export var fallback_invalid := Color(0.9, 0.15, 0.1, 0.95)
## Where the top-left corner of the armed and refused icons sits from the pointer (canvas pixels).
@export var aim_offset_px := Vector2(-19.0, 5.0)

## Seconds the last flash lasted, measured.
var last_flash_s := 0.0

var _flashing := false
var _hover_invalid := false
var _flash_from_ms := 0
var _flash_left := 0.0

@onready var _aim: TextureRect = $Aim
@onready var _invalid: TextureRect = $Invalid
## A Label: in the editor its script (not a tool) does not run.
@onready var _reason: Label = get_node_or_null(^"Reason")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim.visible = false
	_invalid.visible = false
	if Engine.is_editor_hint():
		set_process(false)
		return
	if state:
		state.armed_changed.connect(_on_armed_changed)
		state.said.connect(_on_said)
		state.aim_changed.connect(_on_kind_changed.unbind(1))
	if _reason is RtsRefusalReason:
		(_reason as RtsRefusalReason).bind(state, probe)
	if probe:
		probe.kind_changed.connect(_on_kind_changed)
	_refresh_process()


func _process(delta: float) -> void:
	if _flashing:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flashing = false
			last_flash_s = (Time.get_ticks_msec() - _flash_from_ms) / 1000.0
			_update_invalid()
			_refresh_process()
	_place()


func _on_armed_changed(_kind: StringName, icon: Texture2D) -> void:
	var armed := state != null and state.is_armed()
	_aim.texture = icon
	_aim.visible = armed
	_check_hover()
	_update_invalid()
	_refresh_process()
	_place()


func _on_said(_text: String, cue: StringName) -> void:
	if cue != &"refused":
		return
	_flashing = true
	_flash_from_ms = Time.get_ticks_msec()
	_flash_left = flash_s
	_refresh_process()
	_update_invalid()
	_place()


## Moves with the pointer only while something is drawn.
func _refresh_process() -> void:
	var armed := state != null and state.is_armed()
	set_process(armed or _flashing)


func _on_kind_changed(_kind: StringName) -> void:
	_check_hover()
	_update_invalid()


## The armed thing cannot take what lies under the pointer (empty `accepts` = anything) or would be
## refused there (aim_status).
func _check_hover() -> void:
	_hover_invalid = false
	if state == null or probe == null or not state.is_armed() or probe.kind == RtsTargetProbe.HUD:
		return
	var accepts := state.armed_accepts
	_hover_invalid = (
		state.aim_status != &""
		or not accepts.is_empty() and not accepts.has(String(probe.kind))
	)


func _update_invalid() -> void:
	var show_it := _flashing or _hover_invalid
	_invalid.texture = cues.refused_icon if (cues and show_it) else null
	_invalid.visible = show_it
	queue_redraw()


func _place() -> void:
	var at := probe.pointer_now() if probe else get_viewport().get_mouse_position()
	_aim.position = at + aim_offset_px
	_invalid.position = at + aim_offset_px
	if _aim.visible and _aim.texture == null or _invalid.visible and _invalid.texture == null:
		queue_redraw()


## Fallback without pictures: a circle for the armed icon and a cross for the refusal.
func _draw() -> void:
	if Engine.is_editor_hint():
		return
	if _aim.visible and _aim.texture == null:
		draw_circle(_aim.position + _aim.size * 0.5, _aim.size.x * 0.4, fallback_aim)
	if _invalid.visible and _invalid.texture == null:
		var center := _invalid.position + _invalid.size * 0.5
		var r := _invalid.size.x * 0.4
		draw_line(center + Vector2(-r, -r), center + Vector2(r, r), fallback_invalid, 3.0)
		draw_line(center + Vector2(-r, r), center + Vector2(r, -r), fallback_invalid, 3.0)
